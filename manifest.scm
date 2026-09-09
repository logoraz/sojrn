;; Guix Development Package Manifest
;;
;; Run:
;;
;; guix shell -m manifest.scm
;; export LD_LIBRARY_PATH="$GUIX_ENVIRONMENT/lib:$LD_LIBRARY_PATH"
;; sbcl
;;
;; Note: sojrn-asdf-system extension handles LD_LIBRARY_PATH
;; thereafter, i.e. once the system has been loaded the first time!
;;
;;

(use-modules (gnu packages))

(specifications->manifest
  (list
    "sbcl"                   ; Common Lisp implementation

    ;; CFFI / FFI substrate
    "libffi"                 ; runtime: CFFI's foreign-call backend
    "pkg-config"             ; build: locates C library cflags/libs
    "gcc-toolchain"          ; build: compiles cffi-grovel .c output
    "libfixposix"            ; build+runtime: iolib's POSIX bindings
                             ; (transitive dep, pulled in by dbus)

    "sqlite"                ; persistence

    ;; GTK4 UI stack
    "gtk"                    ; runtime: GTK4 C library
    "pango"
    "cairo"
    "gdk-pixbuf"
    "graphene"))
