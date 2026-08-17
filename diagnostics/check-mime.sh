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
  [test.mdx]='# MDX'
  [.env]='KEY=value'
  [.env.example]='KEY=value'
  [.editorconfig]='root = true'
  [.gitignore]='bin/'
  [.gitattributes]='* text=auto'
  [.gitmodules]='[submodule "example"]'
  [build.cake]='Task("Build");'
  [view.vbhtml]='@Code End Code'
  [policy.rego]='package test'
  [schema.cue]='name: string'
  [default.nix]='{}'
  [document.typ]='= Test'
  [main.gleam]='pub fn main() {}'
  [main.odin]='package main'
  [main.mojo]='fn main():'
  [component.templ]='templ component() {}'
  [Jenkinsfile]='pipeline {}'
  [Vagrantfile]='Vagrant.configure("2")'
  [Tiltfile]='print("test")'
  [Earthfile]='VERSION 0.8'
  [Taskfile.yml]='version: "3"'
  [compose.yml]='services: {}'
  [docker-compose.yml]='services: {}'
)

printf '%-22s %s\n' FILE MIME
printf '%-22s %s\n' '----------------------' '------------------------------'
for name in "${!samples[@]}"; do
  printf '%s\n' "${samples[$name]}" > "$tmp/$name"
  mime="$(xdg-mime query filetype "$tmp/$name" 2>/dev/null || file --mime-type -b "$tmp/$name")"
  printf '%-22s %s\n' "$name" "$mime"
done | sort
