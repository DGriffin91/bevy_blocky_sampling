use bevy::{
    asset::AssetServerSettings,
    prelude::*,
    reflect::TypeUuid,
    render::render_resource::{AsBindGroup, ShaderRef},
};

fn main() {
    App::new()
        .insert_resource(AssetServerSettings {
            watch_for_changes: true,
            ..default()
        })
        .add_plugins(DefaultPlugins)
        .add_plugin(MaterialPlugin::<BlockyMaterial>::default())
        .add_startup_system(setup)
        .add_system(rotate)
        .add_system(update_sampling_mode)
        .run();
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<BlockyMaterial>>,
    asset_server: Res<AssetServer>,
) {
    // Grass image
    let grass = asset_server.load("textures/grass.png");

    // BlockyMaterial
    let material = materials.add(BlockyMaterial {
        sampling_mode: 2,
        base_color_texture: Some(grass),
    });

    // cube
    commands.spawn().insert_bundle(MaterialMeshBundle {
        mesh: meshes.add(Mesh::from(shape::Cube { size: 2.0 })),
        transform: Transform::from_xyz(0.0, 0.0, 0.0),
        material,
        ..default()
    });

    // light 1
    commands.spawn_bundle(PointLightBundle {
        transform: Transform::from_translation(Vec3::new(-5.0, 2.0, 10.0)),
        point_light: PointLight {
            intensity: 2000.0,
            ..default()
        },
        ..default()
    });

    // light 2
    commands.spawn_bundle(PointLightBundle {
        transform: Transform::from_translation(Vec3::new(7.0, 2.0, -2.0)),
        point_light: PointLight {
            intensity: 2000.0,
            ..default()
        },
        ..default()
    });

    // camera
    commands.spawn_bundle(Camera3dBundle {
        transform: Transform::from_xyz(-2.0, 2.5, 5.0).looking_at(Vec3::ZERO, Vec3::Y),
        ..default()
    });

    println!("Press 1 for linear sampling");
    println!("Press 2 for nearest neighbor sampling");
    println!("Press 3 for antialiased blocky sampling");
}

/// Rotates the cube
fn rotate(time: Res<Time>, mut query: Query<&mut Transform, With<Handle<Mesh>>>) {
    for mut transform in query.iter_mut() {
        transform.rotation *= Quat::from_rotation_x(0.25 * time.delta_seconds());
        transform.rotation *= Quat::from_rotation_z(0.25 * time.delta_seconds());
    }
}

/// Change sampling mode with keys 1/2/3
fn update_sampling_mode(
    keys: Res<Input<KeyCode>>,
    mut materials: ResMut<Assets<BlockyMaterial>>,
    material_handles: Query<&Handle<BlockyMaterial>>,
) {
    let mut new_mode = None;
    if keys.just_pressed(KeyCode::Key1) {
        new_mode = Some(0);
    }
    if keys.just_pressed(KeyCode::Key2) {
        new_mode = Some(1);
    }
    if keys.just_pressed(KeyCode::Key3) {
        new_mode = Some(2);
    }

    //If one of the keys was pressed, set the new setting on all BlockyMaterials
    if let Some(new_mode) = new_mode {
        for mat_handle in material_handles.iter() {
            if let Some(mut mat) = materials.get_mut(mat_handle) {
                mat.sampling_mode = new_mode;
            }
        }
    }
}

/// The Material trait is very configurable, but comes with sensible defaults for all methods.
/// You only need to implement functions for features that need non-default behavior. See the Material api docs for details!
impl Material for BlockyMaterial {
    fn fragment_shader() -> ShaderRef {
        "shaders/blocky.wgsl".into()
    }
}

// This is the struct that will be passed to your shader
#[derive(AsBindGroup, Debug, Clone, TypeUuid)]
#[uuid = "1b2a3c6b-6642-4f87-a2df-24816dffcd82"]
pub struct BlockyMaterial {
    #[uniform(0)]
    sampling_mode: u32,
    #[texture(1)]
    #[sampler(2)]
    pub base_color_texture: Option<Handle<Image>>,
}
