Camera :: struct {
    position: Vector3;
    forward:  Vector3;
    right:    Vector3;
    up:       Vector3;

    fov: Degrees = 70.0;
    speed := 0.02;
}

camera_make :: (position: Vector3, look_at: Vector3, up_ref := Vector3.{0, 1, 0}, fov: Degrees = 70.0) -> Camera {
    camera: Camera;

    camera.position = position;
    camera.forward  = normalize(look_at - position);
    camera.right    = normalize(cross_product(up_ref, camera.forward));
    camera.up       = cross_product(camera.forward, camera.right);
    camera.fov      = fov;

    return camera;
}

perspective :: (fov_y: Radians, aspect: float, near: float, far: float) -> Matrix4 {
    // @Note: https://github.com/g-truc/glm/blob/master/glm/ext/matrix_clip_space.inl#L265-L278
    tan_half_fov_y := tan(fov_y * 0.5);

    result: Matrix4;
    result._11 = 1.0 / (aspect * tan_half_fov_y);
    result._22 = -1.0 / (tan_half_fov_y);    // @Note: normally this would be positive but Vulkan is stupid and flips the y
    result._33 = far / (far - near);
    result._34 = 1.0;
    result._43 = -(far * near) / (far - near);

    return result;
}

look_at :: (from: Vector3, to: Vector3, up_ref := Vector3.{0, 1, 0}) -> Matrix4 {
    camera := camera_make(from, to, up_ref);
    return look_at(camera);
}

look_at :: (camera: Camera) -> Matrix4 {
    // @Note: https://github.com/g-truc/glm/blob/master/glm/ext/matrix_transform.inl#L176-L196
    result    :=  make_matrix_from_columns(camera.right, camera.up, camera.forward);
    result._41 = -dot_product(camera.right, camera.position);
    result._42 = -dot_product(camera.up, camera.position);
    result._43 = -dot_product(camera.forward, camera.position);

    return result;
}
