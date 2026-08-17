#!/usr/bin/env bash
set -Eeuo pipefail

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

declare -A samples=(
  [test.cs]='class Test {}'
  [test.csproj]='<Project Sdk="Microsoft.NET.Sdk" />'
  [test.slnx]='<Solution />'
  [test.razor]='<h1>Test</h1>'
  [test.http]='GET https://example.com/'
  [test.proto]='syntax = "proto3";'
  [test.tf]='terraform {}'
  [test.jsonl]='{"ok":true}'
  [Dockerfile]='FROM scratch'
  [test.hta]='<html></html>'
  [test.contact]='test'
)

printf '%-22s %s\n' FILE MIME
printf '%-22s %s\n' '----------------------' '------------------------------'
for name in "${!samples[@]}"; do
  printf '%s\n' "${samples[$name]}" > "$tmp/$name"
  mime="$(xdg-mime query filetype "$tmp/$name" 2>/dev/null || file --mime-type -b "$tmp/$name")"
  printf '%-22s %s\n' "$name" "$mime"
done | sort
