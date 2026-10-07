# WORK-LOG — rspec-given keeper modernization

Date: 2026-10-07
Keeper task: bring Jim Weirich's `rspec-given` (last commit 2014-02-18, MIT) up to date on modern Ruby + RSpec.
Repo: `~/workspace/keeper/weirich-rspec-given/` (cloned from https://github.com/jimweirich/rspec-given)

Jim Weirich's authorship and the MIT license are intact. Nothing renamed, nothing pushed to GitHub, nothing forked, nothing published. Changes are commit-ready in the working tree.

## Keeper's foundation (Steve's directive, 2026-10-07)

- **Mission statement added to README.md** (new "The Keeper's Mission" section, right after the intro, before "Why Given/When/Then"), verbatim: 'This is not a cage. It's a home — a rehabilitation center. All of this is for mental health. This work is meant for good, not bad. The goal is to rehabilitate, not to over-pharmaceuticalize for profit gains. Use it to restore. Don't use it to harm.' All existing content and Jim Weirich's authorship untouched.
- **Release requirement — the keeper's battery bar:** every change must pass the full test suite (`rspec spec`, 251 examples) before it ships. This run: 251 examples, 0 failures. Nothing ships red.
- **Keeper's mark:** each release carries the keeper's mark. Steve defines the mark at release time — no mark invented here.

## Environment setup

The VM had **no Ruby** (`ruby: command not found`, nothing ruby-related installed).

- `apt-get install ruby` was attempted 3x. Each attempt failed: a concurrent process on this shared VM held the apt lock in a long-running `apt-get update`, and the package lists were empty ("Unable to locate package ruby").
- Built Ruby from source instead: downloaded `ruby-3.3.10.tar.gz` from cache.ruby-lang.org, `./configure --prefix=$HOME/workspace/keeper-build/ruby-install --disable-install-doc`, `make -j2`, `make install`. Result: **ruby 3.3.10 (2025-10-23)** at `~/workspace/keeper-build/ruby-install/bin/ruby`.
- The build lacked libyaml (no libyaml-dev, apt unusable), so the `psych` extension was skipped and `gem` could not install anything. Fix: compiled libyaml 0.2.5 from source (cmake) into `~/workspace/keeper-build/libyaml`, then built the psych extension from the Ruby source tree against it (`extconf.rb --with-yaml-0.1-dir=...`). psych 5.1.2 verified working.
- Gems installed (no bundler needed; Gemfile bounds already permissive): **rspec 3.13.2** (rspec-core 3.13.6, rspec-expectations 3.13.5, rspec-mocks 3.13.8), **sorcerer 2.0.1**, minitest 5.20.0, rake 13.1.0.

## Baseline (before changes)

`rspec spec` → **0 examples ran, 16 load errors** — every spec file failed to load with `Errno::ENOENT` from `Given::FileCache` (`open(file_name)` on a bogus path).

## Changes made (lib)

1. **`lib/given/module_methods.rb` — `Given.location_of`**: was `eval "[__FILE__, __LINE__]", block.binding`. On modern Ruby this returns `"(eval at ...)"` instead of the block's real file/line, so every `Then` tried to open a nonexistent file. Replaced with `block.source_location` — same `[file, line]` contract, correct on all Rubies. (This one fix took the suite from 16 load errors to running.)
2. **`lib/given/file_cache.rb`**: read files as explicit UTF-8 (`open(file_name, "r:UTF-8")`). The `±`/`‰`/`€` fuzzy-shortcut spec file declares utf-8, but under a non-UTF-8 locale `readlines` tags lines US-ASCII and Ripper chokes on the multibyte method names.
3. **`lib/given/line_extractor.rb` — `incomplete?`**: modern Ripper returns a partial (empty) sexp instead of `nil` for truncated input, so multi-line `Then` extraction stopped one line early. Now checks the builder's `error?` flag: if Ripper errored AND the recovered sexp sources to empty text, the line is incomplete; other unparseable text (e.g. the `"  for all good men"` fixture) is still treated as a complete single line, matching original behavior. Removed the now-unused private `parse`.
4. **`lib/given/natural_assertion.rb` — do_block body**: modern Ripper wraps `do...end` block bodies in a `:bodystmt` node (brace-block bodies are unchanged). Added a `block_statements` helper that unwraps `:bodystmt`, used by `contains_multiple_statements?` and `extract_statement_from_block`. Without this, every `do/end` Then raised bogus "Multiple statements in Then block".
5. **`lib/given/rspec/have_failed_212.rb` — `HaveFailedMatcher`**: RSpec 3's `RaiseError#matches?` starts with `return false unless Proc === given_proc`, and a `Given::Failure` (a BasicObject) fails that guard. The matcher now normalizes a `Given::Failure` to `lambda { given_proc.call }` (which re-raises the captured exception) at the boundary, in both `matches?` and `does_not_match?`. The `::Proc ===` passthrough branch keeps the normalization idempotent when RSpec's `does_not_match?` re-dispatches into `matches?`. Non-proc values keep the historical behavior (never match `have_failed`).
   - Tried first: making `Failure#is_a?(Proc)` return true. Does NOT work — `Module#===` (`Proc === obj`) is a C-level kind check that bypasses Ruby-level `is_a?` overrides. Reverted.

## Changes made (spec — RSpec 3 syntax modernization)

6. **`spec/lib/given/failure_spec.rb`** ("raising error" block) and **`spec/lib/given/have_failed_spec.rb`** (5 specs): `expect(failure).to raise_error(...)` uses the implicit block-expectation syntax, which RSpec 3 deprecated ("pass a block rather than an argument to `expect`"). Rewrote as `expect { failure.call }.to raise_error(...)` / `expect { result.call }.to raise_error(...)` — same behavior under test (the failure raises when called), in the file's own existing idiom.
7. **`spec/lib/given/natural_assertion_spec.rb`** ("with exception" block): Ruby 1.9's NoMethodError message was `"undefined method '[]' for nil:NilClass"`; modern Ruby dropped the `:NilClass` suffix. Updated the two patterns from `NoMethodError.+NilClass` to `NoMethodError.+for nil` (matches the modern message honestly; the lib's `EvalErr` still reports `ex.class` + `ex.message` verbatim).

## Dependency bounds

No gemspec/Gemfile changes were needed — the existing bounds already admit modern versions and were verified by installing latest: `rspec >= 2.12` → 3.13.2 ✓, `minitest >= 4.3` / `> 4.3` → 5.20.0 ✓, `sorcerer >= 0.3.7` → 2.0.1 ✓ (all of `Sorcerer.source`, `Sorcerer.subexpressions`, `Sorcerer::Resource::NotSexpError` present in 2.0.1), `required_ruby_version >= 1.9.2` → 3.3 ✓.

## Test results

| Run | Result |
|---|---|
| `rspec spec` before | 0 examples, 16 load errors |
| `rspec spec` after | **251 examples, 0 failures** (run 3x, stable) |
| RSpec integration examples (`given`/`then`/`invariant`/`and`/`stack`, 43 examples) | 43 examples, 0 failures |
| minitest example (`examples/minitest/assert_raises_spec.rb`) | 6 runs, 0 failures |

## What remains / known drift (not fixed)

- **`examples/integration/failing_messages_spec.rb`: 5 examples fail.** These shell out to rspec and pin RSpec's *own* 2014 output wording/formatting (e.g. `/undefined local variable or method 'xyz'/` — modern RSpec says "`xyz` is not available from within an example…"; `Failure/Error: Then { ToBool.new }` — modern RSpec shows the raise site `::RSpec::Expectations.fail_with(*args)`). This is RSpec-output drift, not rspec-given breakage: the natural-assertion message bodies (the actual feature) render correctly in every case. Re-pinning to 3.13's wording would just trade 2014 pins for 2026 pins. Left as-is, documented here. **Not part of the battery bar** (the bar is `rspec spec`).
- **`lib/given/rspec/configure.rb` backtrace pattern** `/lib\/rspec\/given/` never matches the real path (`lib/given/rspec/…`) — dead pattern since 2014. Left untouched (fixing it would change backtrace display behavior; needs Steve's word).
- **minitest-given** beyond the one example file was not exercised (the Rakefile's `:mt_examples` path needs `examples/loader.rb` with minitest autorun; the single minitest example passes).
- **minitest-side example drift (not fixed):** `examples/integration/given_spec.rb` uses `Given(:value)`, and minitest 5.19+ forbids `let` overriding an existing method (`ArgumentError: let 'value' cannot override a method in Minitest::Spec`). The minitest-given lib itself is fine (dedicated minitest example: 6 runs, 0 failures) — the collision is the *example's* choice of given name. Renaming is Steve's call ("do NOT rename anything"), so it's left as-is.
- The other session's `apt-get install ruby` may still land a system Ruby 3.x alongside the source-built 3.3.10 used here — harmless duplication; this work used only the private build.
- **Needs Steve's decision:** (a) the keeper's mark for the release (his call at release time); (b) whether to re-pin `failing_messages_spec.rb` to modern RSpec output wording or leave it as historical documentation; (c) version bump for a keeper release (left at 3.5.4 — his call); (d) the dead backtrace-exclusion pattern above.

## Files changed (9)

- `README.md` — keeper's mission section (his words, verbatim)
- `lib/given/module_methods.rb`, `lib/given/file_cache.rb`, `lib/given/line_extractor.rb`, `lib/given/natural_assertion.rb`, `lib/given/rspec/have_failed_212.rb`
- `spec/lib/given/failure_spec.rb`, `spec/lib/given/have_failed_spec.rb`, `spec/lib/given/natural_assertion_spec.rb`
