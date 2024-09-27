# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - Unreleased

- Load defd functions via `Dx.load`, `Dx.load!`, `Dx.get` and `Dx.get!`

### Breaking changes

- `Dx.load`, `Dx.load!`, `Dx.get` and `Dx.get!` are now macros and
  must be required or imported when used.

## [0.3.3] - Unreleased

### Features

- Support piping into `Dx.Defd` functions `load!`, `load`, `get!` and `get`
- Translate to SQL when used within `Enum.filter` function: `>`, `<`, `or`, `Enum.any?/2`, `Enum.all?`

### Fixes

- Fix passing function references to `Enum` supporting scopes (translation to SQL)

## [0.3.2] - 2024-06-27

- Introduce defd functions with automatic batched data loading (#22) - @arnodirlam

This is a fully backward-compatible preview version of the new
Dx approach. See the README for an introduction and more details.

A breaking version will be released as v0.4.0

## [0.3.1] - 2024-05-13

- Configure dataloader (#21) - @ftes
- Handle `:timeout` atom as error (#20) - @ftes

## [0.3.0] - 2022-07-10

Initial release
