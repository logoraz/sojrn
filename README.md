# SOJRN: A Declarative Transactional Keeper of Secrets, Notes, & Config

<p align="center"> <img src="assets/cl-icon.svg" width="200"/> </p>

A Lisp-native personal state manager — secrets, notes, and dotfiles/config, all
declaratively tracked in a SQLite-backed database rather than scattered across
plaintext files and ad-hoc tools. Originally built as a config/dotfile
deployment tool; that piece still works and remains as a side feature, but the
primary focus going forward is a password/secrets/notes manager — a
self-built alternative to things like KeePassXC.

PS: I am building this for my own use and my own amusement — not a bid for The
One True [anything] Tool. Feel free to poke around, steal ideas, or use it
yourself if it looks fun.

## Dependencies

Dependencies (see Guix manifest.scm for reference). These are generic library
dependencies; Linux users can install them via their distro's package manager:
- SBCL
- [ocicl](https://github.com/ocicl/ocicl)
- sqlite (libsqlite3)
- gtk, pango, cairo, gdk-pixbuf, graphene
- libffi, pkg-config, gcc-toolchain, libfixposix

[ocicl](https://github.com/ocicl/ocicl) handles CL dependencies, however, you
need to git install the following:

```bash
# project root
ocicl install git+https://github.com/crategus/cl-cffi-gtk4@master
ocicl install git+https://github.com/crategus/cl-cffi-gdk-pixbuf
ocicl install git+https://github.com/logoraz/sojrn-asdf-system
```

## Installation & Usage (WIP)

Actively under construction...

## References:

- [ocicl](https://github.com/ocicl/ocicl) — Common Lisp system manager used
  throughout this project.
- [sojrn-asdf-system](https://github.com/logoraz/sojrn-asdf-system) - Custom ASDF
  system extension for docs and executable generation
- [bordeaux-threads](https://github.com/sionescu/bordeaux-threads) — portable
  threading, used for the session lock and background connection thread.
- [cl-ppcre](https://github.com/edicl/cl-ppcre) — regular expressions, used in
  `ansi-color.lisp`.
- [trivial-gray-streams](https://github.com/trivial-gray-streams/trivial-gray-streams)
  — Gray streams portability layer, used in `ansi-color.lisp`'s colored-output
  stream class.
- [osicat](https://github.com/skypeeker/osicat) — POSIX bindings used by
  `config-manager.lisp`.
- [cl-dbi](https://github.com/fukamachi/cl-dbi) — database abstraction layer
  backing `database.lisp`.
- [cl-cffi-gtk4](https://github.com/crategus/cl-cffi-gtk4) and its sibling
  libraries:
  - [cl-cffi-gdk-pixbuf](https://github.com/crategus/cl-cffi-gdk-pixbuf)
  - [cl-cffi-glib](https://github.com/crategus/cl-cffi-glib),
  - [cl-cffi-cairo](https://github.com/crategus/cl-cffi-cairo),
  - [cl-cffi-pango](https://github.com/crategus/cl-cffi-pango),
  - [cl-cffi-graphene](https://github.com/crategus/cl-cffi-graphene),
- [FiveAM](https://github.com/sionescu/fiveam) — the testing framework backing
  `sojrn/tests`.
- [3bmd](https://github.com/3b/3bmd) — Markdown rendering used by
  `sojrn-asdf-system`'s doc generator.
- [Common Lisp: A Gentle Introduction to Symbolic
  Computation](https://www.cs.cmu.edu/~dst/LispBook/)
  - source for the `sdraw`/`dtrace` learning tools in `learn-cl`.
- [GNU Guix](https://guix.gnu.org/) - The system this project was develop on —
  the environment `manifest.scm` targets.

## License

```lisp
(defmacro license-terms (system . plist)
  "See LICENSE for the actual legally-binding, non-parenthesized version."
  (declare (optimize (safety 0))) ; use at your own risk
  `(list :system ',system ,@plist))

(license-terms sojrn
  :type        '(:|LGPL-2.1-only WITH LLGPL| . "https://spdx.org/licenses/LLGPL.html")
  :permissions '(:use :copy :modify :distribute :link)
  :conditions  '(:include-copyright-notice
                 :disclose-source-lib
                 :same-license-lib
                 :state-changes
                 :lisp-linking)
  :warranty    nil)
```

↳ [LICENSE](LICENSE)
