#!/usr/bin/env bash
set -Eeuo pipefail

mimes=(
  text/x-csharp
  text/x-fsharp
  text/x-go
  text/x-python
  application/x-php
  text/javascript
  text/x-typescript
  text/x-typescript-jsx
  text/x-java
  text/x-kotlin
  text/rust
  text/x-c++src
  text/x-swift
  text/x-zig
  application/sql
  text/x-razor
  text/x-containerfile
)

printf '%-32s %s\n' MIME DEFAULT_APPLICATION
printf '%-32s %s\n' '--------------------------------' '------------------------------'
for mime in "${mimes[@]}"; do
  default="$(xdg-mime query default "$mime" 2>/dev/null || true)"
  printf '%-32s %s\n' "$mime" "${default:-(not set)}"
done
