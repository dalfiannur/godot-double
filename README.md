# godot-double

Editor Godot **double precision** dan **Terrain3D** untuknya, untuk dunia
open-world skala besar (dunia 1:1 per kabupaten/provinsi di
`godot-terrain-generator`). Godot tidak merilis binary double, jadi keduanya
di-*compile* dari source oleh `build.sh`.

| Komponen | Versi | Catatan |
|---|---|---|
| Godot | 4.7.2-stable | `precision=double`, tanpa Mono (C#) |
| Terrain3D | 1.0.2-stable | + godot-cpp master `e103d34` dan `patches/` |

## Pakai

```sh
./build.sh                    # editor (±11 menit, 12 core) lalu Terrain3D (±4 menit)
./install.sh editor           # perintah `godot-double` di ~/.local/bin
./install.sh project ~/Workspace/tools/godot-terrain-generator
godot-double --path ~/Workspace/tools/godot-terrain-generator -e
```

Hasil build ada di `dist/` (tidak di-commit; ±175 MB). Source di `~/.local/src`
(ubah lewat `SRC=...`) dan dipakai ulang, jadi build berikutnya inkremental.
Butuh git, toolchain C++ (gcc/clang) dan python3; `scons` dipasang sendiri ke
venv kalau belum ada. Ruang disk: ±6 GB untuk source dan object file.

Pertama kali dijalankan, `godot-double` butuh beberapa menit untuk
mengompilasi shader; setelah itu normal.

## Kenapa godot-cpp master dan patch

- godot-cpp bawaan Terrain3D 1.0.2 (cabang 4.4) memakai hash method API 4.4.
  Build single Godot 4.7 punya fallback untuk hash lama itu, build double tidak:
  engine crash di `PhysicsServer3D.body_add_shape` saat Terrain3D membuat
  collision.
- Generator godot-cpp 4.4 tidak bisa membaca API 4.7, jadi dipakai godot-cpp
  master dengan API hasil dump dari editor double itu sendiri
  (`custom_api_file`), sehingga hash dan ukuran tipe (`real_t` = double) cocok.
- `patches/terrain3d-1.0.2-godot-cpp-master.patch` menyesuaikan source Terrain3D
  ke godot-cpp baru: `#include <functional>` (dulu ikut ter-include) dan
  `Math_PI`/`Math_TAU` → `Math::PI`/`Math::TAU`.

## Di project

`install.sh project` menaruh `libterrain.linux.{debug,release}.double.x86_64.so`
di samping library Terrain3D yang asli dan mendaftarkannya di
`terrain.gdextension` dengan tag fitur `double`. Godot single tetap memakai
library aslinya, jadi project bisa dibuka dengan kedua editor.

Kode project yang memakai tipe "real" harus netral terhadap presisi, misalnya
`HeightMapShape3D.map_data` adalah `PackedFloat64Array` di build double; isi
array milik shape itu sendiri alih-alih membuat `PackedFloat32Array`.

## Belum

- Export template double (`target=template_release precision=double`) untuk
  game hasil export.
- Platform selain Linux x86_64.
