# Automated RetreatUI releases

RetreatUI releases are created by `.github/workflows/publish-release.yml`.

The workflow packages only:

- `RetreatUI`
- `RetreatUI_Classes`

It validates both `.toc` versions, validates the ZIP structure, prevents duplicate tags, creates the GitHub release and uploads the finished ZIP asset.

## Release order

For every release, update files in this order:

1. Commit all addon code changes.
2. Set the same version in:
   - `RetreatUI/RetreatUI.toc`
   - `RetreatUI_Classes/RetreatUI_Classes.toc`
3. Add the release notes file under `.github/release-notes/`.
4. Update `.github/release-manifest.json` last.

Updating the manifest triggers the release workflow automatically.

## Beta example

```json
{
  "publish": true,
  "version": "1.0.12-beta.1",
  "title": "RetreatUI v1.0.12 Beta 1",
  "prerelease": true,
  "notes_file": ".github/release-notes/1.0.12-beta.1.md"
}
```

Required `.toc` value:

```text
## Version: 1.0.12-beta.1
```

The workflow creates:

```text
Tag: v1.0.12-beta.1
Asset: RetreatUI_v1.0.12-beta.1.zip
Release type: Pre-release
```

## Stable example

```json
{
  "publish": true,
  "version": "1.0.12",
  "title": "RetreatUI v1.0.12",
  "prerelease": false,
  "notes_file": ".github/release-notes/1.0.12.md"
}
```

Required `.toc` value:

```text
## Version: 1.0.12
```

The workflow creates a normal release and marks it as the latest stable release.

## Safety checks

Publishing fails without creating a release when:

- either addon folder is missing
- either `.toc` file is missing
- the two `.toc` versions do not match
- the `.toc` version does not match the manifest
- the release notes file is missing
- a prerelease suffix is paired with `prerelease: false`
- a stable version is paired with `prerelease: true`
- the tag or release already exists
- the ZIP contains unexpected root folders

Set `publish` to `false` to keep the manifest inactive.
