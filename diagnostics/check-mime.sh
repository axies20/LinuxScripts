#!/usr/bin/env bash
set -Eeuo pipefail

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

declare -A samples=(
  [test.cs]='class Test {}'
  [test.fs]='module Test'
  [test.csproj]='<Project Sdk="Microsoft.NET.Sdk" />'
  [test.slnx]='<Solution />'
  [test.razor]='<h1>Test</h1>'
  [test.go]='package main'
  [go.mod]='module example.com/test'
  [test.py]='print("hello")'
  [test.pyx]='cdef int value'
  [test.php]='<?php echo "hello"; ?>'
  [test.blade.php]='{{ $value }}'
  [test.js]='console.log("hello")'
  [test.ts]='const value: number = 1;'
  [test.tsx]='export const App = () => <div />;'
  [test.vue]='<template><div /></template>'
  [test.svelte]='<script>let value = 1;</script>'
  [test.java]='class Test {}'
  [test.kt]='fun main() {}'
  [test.rs]='fn main() {}'
  [test.cpp]='int main() {}'
  [test.swift]='print("hello")'
  [test.zig]='pub fn main() void {}'
  [test.rb]='puts "hello"'
  [test.lua]='print("hello")'
  [test.R]='print("hello")'
  [test.ps1]='Write-Host "hello"'
  [test.sql]='select 1;'
  [test.graphql]='query Test { __typename }'
  [test.proto]='syntax = "proto3";'
  [test.tf]='terraform {}'
  [test.prisma]='datasource db { provider = "postgresql" }'
  [test.jsonl]='{"ok":true}'
  [Dockerfile]='FROM scratch'
  [test.container]='[Container]'
  [Makefile]='all:\n\t@true'
  [CMakeLists.txt]='cmake_minimum_required(VERSION 3.20)'
  [test.prompty]='name: test'
  [test.hta]='<html></html>'
)

printf '%-24s %s\n' FILE MIME
printf '%-24s %s\n' '------------------------' '-----------------------------------'
for name in "${!samples[@]}"; do
  printf '%b\n' "${samples[$name]}" > "$tmp/$name"
  mime="$(xdg-mime query filetype "$tmp/$name" 2>/dev/null || file --mime-type -b "$tmp/$name")"
  printf '%-24s %s\n' "$name" "$mime"
done | sort
