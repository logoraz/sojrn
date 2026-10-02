(uiop:define-package :sojrn/startup
  (:use :cl
        :sojrn/base/config-manager
        :sojrn/base/database
        :sojrn/persistence)
  ;; User Config API
  (:export #:*config-mgr*
           #:*user-sojrn-directory*
           #:*config-spec*
           #:*user-config-loaded*)
  ;; Cache/Persistence API
  (:export #:*sojrn-db-status*
           #:*sojrn-cache-directory*)
  (:documentation "Handles Sojrn's startup sequence."))

(in-package :sojrn/startup)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Defaults: Configuration/Cache & Persistence Setup

(defvar *config-mgr* (make-instance 'config-manager)
  "The default config-manager instance for user and defaults configs.")

(defvar *user-sojrn-directory*
  (merge-pathnames #P"sojrn/" (uiop:xdg-config-home))
  "Directory holding the user's sojrn config.lisp.")

(defparameter *config-spec* nil
  "Config spec built by load-user-config's defaults branch when no
user config.lisp exists; nil otherwise.")

(defparameter *user-config-loaded* nil
  "List of config-objects currently held by *config-mgr*, set after
load-user-config runs.")

(defvar *sojrn-cache-directory*
  (merge-pathnames #P"sojrn/" (uiop:xdg-cache-home))
  "Sojrn cache directory for persistent runtime data (e.g. the
deployment database).")

(defvar *db-path*
  (merge-pathnames "persistence/deployments.db" *sojrn-cache-directory*)
  "Default path for the SQLite database.")

(defvar *sojrn-db-status* nil
  "Status message from the most recent database initiliazation.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; User Config Scaffolding
;;;

(defun user-config-exists? ()
  "Check whether user-config directory and files exists"
  (probe-file (merge-pathnames "config.lisp" *user-sojrn-directory*)))

(defun load-user-config ()
  "Load the user's config if present, else set up and apply
defaults. Returns the manager's current configs."
  (if (user-config-exists?)
      (load (merge-pathnames "config.lisp"
                             *user-sojrn-directory*))
      (let ((sojrn-dir (merge-pathnames #P"files/common-lisp/"
                                        (asdf:system-source-directory :sojrn))))
        (ensure-directories-exist *user-sojrn-directory*)
        (setf *config-spec*
              `(("SBCL Config"
                 ,(merge-pathnames #P"dot-sbclrc.lisp"
                                   (uiop:native-namestring sojrn-dir))
                 "~/.sbclrc"
                 :spec :symlink :type :file)))
        (add-configs *config-mgr* *config-spec*)))
  (configs *config-mgr*))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Cache & Persistence Scaffolding
;;;

(defun create-sojrn-cache-persistence ()
  "Checks for/Create cache directory & intializes the database."
  ;; Ensure the database directory exists
  (uiop:ensure-all-directories-exist (list *db-path*))
  (initialize-database *db-path*))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Load User Config and Persistence Cache
;;;

(setf *user-config-loaded* (load-user-config))
(setf *sojrn-db-status* (create-sojrn-cache-persistence))
