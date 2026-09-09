(defsystem "sojrn"
  :description "A Declarative Transactional Keeper of Secretes, Notes, & Config."
  :author "Erik P Almaraz <erikalmaraz@fastmail.com>"
  :license "GPL-2.0-only"
  :version (:read-file-form "version.sexp" :at (0 1))
  :defsystem-depends-on ("sojrn-asdf-system")
  :class :sojrn-asdf-system-extension
  :depends-on ("sojrn-asdf-system"
               "bordeaux-threads"
               "cl-ppcre"
               "trivial-gray-streams"
               "osicat"
               "cl-dbi"
               "cl-cffi-gtk4"
               "cl-cffi-glib"
               "cl-cffi-gdk-pixbuf"
               "cl-cffi-graphene"
               "cl-cffi-pango"
               "cl-cffi-cairo"
               ;; contrib's
               "sojrn/contrib")
  :components
  ((:module "src"
    :components
    ((:module "lib"
      :components
      ((:file "syntax")
       (:file "ansi-color" :depends-on ("syntax"))))
     (:module "core"
      :depends-on ("lib")
      :components
      ((:file "config-manager")
       (:file "database"       :depends-on ("config-manager"))))
     (:module "ui"
      :depends-on ("lib" "core")        ; future depedencies
      :components
      ((:file "app")))
     (:file "persistence" :depends-on ("core" "lib"))
     (:file "startup"     :depends-on ("core" "persistence"))
     (:file "sojrn"       :depends-on ("startup" "persistence" "ui")))))

  :in-order-to ((test-op (test-op "sojrn/tests")))
  :long-description "
A Declarative Transactional Keeper of Scecretds, Notes, & Config.
")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Register System Names/Aliases

(register-system-packages "bordeaux-threads"   '(:bt :bt2))
(register-system-packages "cl-dbi"             '(:dbi))
(register-system-packages "fiveam"             '(:5am))
(register-system-packages "cl-cffi-gtk4"       '(:gtk :gdk))
;; cl-cffi-gtk4 dependencies
(register-system-packages "cl-cffi-glib"       '(:gobject :glib :gio))
(register-system-packages "cl-cffi-gdk-pixbuf" '(:gdk-pixbuf))
(register-system-packages "cl-cffi-graphene"   '(:graphene))
(register-system-packages "cl-cffi-pango"      '(:pango))
(register-system-packages "cl-cffi-cairo"      '(:cairo))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Subsystems

(defsystem "sojrn/docs"
  :class :sojrn-doc-system
  :depends-on ("sojrn"))


(defsystem "sojrn/tests"
  :description "Unit tests"
  :depends-on ("sojrn"
               "fiveam")
  :components
  ((:module "tests"
    :components
    ((:file "suite"))))
  :perform (test-op (o c) (symbol-call :fiveam :run!
                                       (find-symbol "SUITE"
                                                    :sojrn/tests/suite))))

(defsystem "sojrn/executable"
  :description "Build executable"
  :class :sojrn-exec-system
  :depends-on ("sojrn")
  :build-operation "program-op"
  :build-pathname "dist/sojrn"
  :entry-point "sojrn:main")

(defsystem "sojrn/contrib"
  :description "Discover and register contrib modules for dynamic loading."
  :perform
  (load-op
   (o c)
   (let* ((root (asdf:system-source-directory "sojrn"))
          (pat  (merge-pathnames "*/*.asd" (merge-pathnames "contrib/" root)))
          (dirs (loop :for asd :in (directory pat)
                      :collect (list :directory
                                     (make-pathname
                                      :directory (pathname-directory asd))))))
     (asdf:initialize-source-registry
      (list* :source-registry
             (append dirs (list :inherit-configuration)))))))
