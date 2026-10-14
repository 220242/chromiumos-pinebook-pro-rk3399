/*
 * Copyright 2026 The chromiumos-pinebook-pro-rk3399 Authors
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 *
 * minigbm backend for the Panfrost render node (Mali Midgard/Bifrost with an
 * upstream kernel), for boards whose display driver has no render node of
 * its own, such as the Pinebook Pro (RK3399: rockchipdrm + Panfrost).
 *
 * Chrome creates its GBM device on the first render node: ozone for the
 * buffers it composites and scans out, the video decoder for decoded
 * frames, the camera service for camera buffers. Without a backend for
 * "panfrost" every one of those failed ("Couldn't create Gbm Device at
 * /dev/dri/renderD128") and Chrome fell back to software decoding.
 *
 * Buffers are linear Panfrost BOs. The display (rockchipdrm, behind its
 * IOMMU), rkvdec and the Hantro VPU import them as dma-bufs. Layouts follow
 * minigbm's rockchip backend, written for the same SoC: NV12 is aligned to
 * 16x16 macroblocks with room after the image for the motion vectors rkvdec
 * stores there (128 bytes per macroblock).
 *
 * The board overlay's profile.bashrc copies this file into minigbm and
 * builds it with -DDRV_PANFROST.
 */

#ifdef DRV_PANFROST

#include <drm/panfrost_drm.h>
#include <errno.h>
#include <inttypes.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <xf86drm.h>

#include "drv_helpers.h"
#include "drv_priv.h"
#include "util.h"

static const uint32_t scanout_render_formats[] = { DRM_FORMAT_ABGR8888, DRM_FORMAT_ARGB8888,
						   DRM_FORMAT_BGR888,	DRM_FORMAT_RGB565,
						   DRM_FORMAT_XBGR8888, DRM_FORMAT_XRGB8888 };

static const uint32_t texture_only_formats[] = { DRM_FORMAT_NV12, DRM_FORMAT_YVU420,
						 DRM_FORMAT_YVU420_ANDROID };

static int panfrost_init(struct driver *drv)
{
	struct format_metadata metadata;

	metadata.tiling = 0;
	metadata.priority = 1;
	metadata.modifier = DRM_FORMAT_MOD_LINEAR;

	drv_add_combinations(drv, scanout_render_formats, ARRAY_SIZE(scanout_render_formats),
			     &metadata, BO_USE_RENDER_MASK | BO_USE_SCANOUT);

	drv_add_combinations(drv, texture_only_formats, ARRAY_SIZE(texture_only_formats), &metadata,
			     BO_USE_TEXTURE_MASK);

	/* NV12 for the camera, display, decoding and encoding. */
	drv_modify_combination(drv, DRM_FORMAT_NV12, &metadata,
			       BO_USE_CAMERA_READ | BO_USE_CAMERA_WRITE | BO_USE_SCANOUT |
				   BO_USE_HW_VIDEO_DECODER | BO_USE_HW_VIDEO_ENCODER);

	drv_modify_linear_combinations(drv);

	/*
	 * R8 is used for HAL_PIXEL_FORMAT_BLOB: JPEG snapshots from the camera and
	 * input/output buffers of the hardware decoder and encoder.
	 */
	drv_add_combination(drv, DRM_FORMAT_R8, &metadata,
			    BO_USE_CAMERA_READ | BO_USE_CAMERA_WRITE | BO_USE_SW_MASK |
				BO_USE_LINEAR | BO_USE_HW_VIDEO_DECODER | BO_USE_HW_VIDEO_ENCODER |
				BO_USE_GPU_DATA_BUFFER | BO_USE_SENSOR_DIRECT_DATA);

	return 0;
}

static int panfrost_bo_create_with_modifiers(struct bo *bo, uint32_t width, uint32_t height,
					     uint32_t format, const uint64_t *modifiers,
					     uint32_t count)
{
	int ret;
	struct drm_panfrost_create_bo create = { 0 };

	if (format == DRM_FORMAT_NV12) {
		uint32_t w_mbs = DIV_ROUND_UP(width, 16);
		uint32_t h_mbs = DIV_ROUND_UP(height, 16);

		drv_bo_from_format(bo, w_mbs * 16, 1, h_mbs * 16, format);
		/* Room after the image for rkvdec's motion vectors. */
		bo->meta.total_size += w_mbs * h_mbs * 128;
	} else {
		uint32_t stride;

		if (!drv_has_modifier(modifiers, count, DRM_FORMAT_MOD_LINEAR)) {
			errno = EINVAL;
			drv_loge("panfrost: no usable modifier found\n");
			return -errno;
		}

		/*
		 * The ARM L1 cache line is 64 bytes; YV12 chroma planes need 64-byte
		 * alignment too, so its luma rows are aligned to 128 bytes.
		 */
		stride = drv_stride_from_format(format, width, 0);
		if (format == DRM_FORMAT_YVU420 || format == DRM_FORMAT_YVU420_ANDROID)
			stride = ALIGN(stride, 128);
		else
			stride = ALIGN(stride, 64);

		drv_bo_from_format(bo, stride, 1, height, format);
	}

	if (bo->meta.total_size > UINT32_MAX) {
		drv_loge("panfrost: buffer too large (%" PRIu64 ")\n",
			 (uint64_t)bo->meta.total_size);
		return -EINVAL;
	}

	create.size = (uint32_t)bo->meta.total_size;
	/* Data buffers: never executed by the GPU. */
	create.flags = PANFROST_BO_NOEXEC;

	ret = drmIoctl(bo->drv->fd, DRM_IOCTL_PANFROST_CREATE_BO, &create);
	if (ret) {
		drv_loge("DRM_IOCTL_PANFROST_CREATE_BO failed (size=%u)\n", create.size);
		return -errno;
	}

	bo->handle.u32 = create.handle;
	bo->meta.format_modifier = DRM_FORMAT_MOD_LINEAR;

	return 0;
}

static int panfrost_bo_create(struct bo *bo, uint32_t width, uint32_t height, uint32_t format,
			      uint64_t use_flags)
{
	uint64_t modifiers[] = { DRM_FORMAT_MOD_LINEAR };

	return panfrost_bo_create_with_modifiers(bo, width, height, format, modifiers,
						 ARRAY_SIZE(modifiers));
}

static void *panfrost_bo_map(struct bo *bo, struct vma *vma, uint32_t map_flags)
{
	int ret;
	struct drm_panfrost_mmap_bo map = { 0 };

	map.handle = bo->handle.u32;
	ret = drmIoctl(bo->drv->fd, DRM_IOCTL_PANFROST_MMAP_BO, &map);
	if (ret) {
		drv_loge("DRM_IOCTL_PANFROST_MMAP_BO failed\n");
		return MAP_FAILED;
	}

	vma->length = bo->meta.total_size;
	return mmap(NULL, bo->meta.total_size, drv_get_prot(map_flags), MAP_SHARED, bo->drv->fd,
		    map.offset);
}

const struct backend backend_panfrost = {
	.name = "panfrost",
	.init = panfrost_init,
	.bo_create = panfrost_bo_create,
	.bo_create_with_modifiers = panfrost_bo_create_with_modifiers,
	.bo_destroy = drv_gem_bo_destroy,
	.bo_import = drv_prime_bo_import,
	.bo_export = drv_prime_bo_export,
	.bo_map = panfrost_bo_map,
	.bo_unmap = drv_bo_munmap,
	.resolve_format_and_use_flags = drv_resolve_format_and_use_flags_helper,
};

#endif
