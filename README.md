# Homebrew Tap

<!-- BEGIN GENERATED PACKAGES -->

## git-this-bread

A suite of git utilities for developers who knead to understand their repos.

```bash
brew install jdevera/tap/git-this-bread
```

See [git-this-bread](https://github.com/jdevera/git-this-bread) for documentation.

<!-- END GENERATED PACKAGES -->

## Updating this README

The [Update README workflow](.github/workflows/update-readme.yml) automatically
commits package list changes after pushes to `main`. It can also be run manually
from GitHub Actions. Pull requests validate the generator and package metadata.

The package list is generated from the `desc` and `homepage` metadata in the tap's
root-level formulas, `Formula/`, and `Casks/`. Metadata must use literal quoted
strings. Ruby is the only local requirement. To regenerate it locally:

```bash
ruby scripts/update_readme.rb
```

Use `ruby scripts/update_readme.rb --check` to check for stale content without
changing the README. Edit prose outside the generated markers directly.
