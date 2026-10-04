(uiop:define-package :sojrn/base/config-manager
  (:use :cl
        :sojrn/lib/ansi-color)
  (:import-from :osicat
                #:make-link
                #:read-link
                #:file-kind)
  (:local-nicknames (#:u :uiop)
                    (#:ufs :uiop/filesystem)
                    (#:upn :uiop/pathname))
  ;; Classes
  (:export #:config-object
           #:config-manager)
  ;; Config Accessors
  (:export #:config-name
           #:config-source
           #:config-place
           #:config-spec
           #:config-type)
  ;; Manager Methods
  (:export #:add-config
           #:add-configs
           #:remove-config
           #:find-config
           #:list-configs
           #:deploy-configs
           #:clear-configs
           #:configs
           #:config-count)
  ;; Utilities
  (:export #:expand-pathname
           #:symlinkp
           #:symlink-target
           #:symlink-update-needed-p
           #:create-symlink
           #:copy-directory)
  ;; Conditions
  (:export #:config-error
           #:source-not-found
           #:deployment-error)
  (:documentation "CLOS-based Configuration Manager"))
(in-package :sojrn/base/config-manager)


;;; Conditions

(define-condition config-error (error)
  ((config :initarg :config :reader config-error-config))
  (:documentation "Base condition for config-manager errors."))

(define-condition source-not-found (warning)
  ((path :initarg :path :reader source-not-found-path))
  (:report (lambda (c stream)
             (format stream "Source path does not exist: ~A"
                     (source-not-found-path c)))))

(define-condition deployment-error (config-error)
  ((action :initarg :action :reader deployment-error-action)
   (reason :initarg :reason :reader deployment-error-reason))
  (:report (lambda (c stream)
             (format stream "Deployment failed for ~A: ~A"
                     (config-name (config-error-config c))
                     (deployment-error-reason c)))))


;;; Classes

(defclass config-object ()
  ((name    :initarg :name :reader config-name :type string
            :documentation "Name of the config")
   (source  :initarg :source :reader config-source :type pathname
            :documentation "Source path")
   (place   :initarg :place :reader config-place :type pathname
            :documentation "Destination path")
   (spec    :initarg :spec :reader config-spec :initform :symlink
            :type (member :copy :symlink)
            :documentation "Transfer method")
   (type    :initarg :type :reader config-type :initform :file
            :type (member :file :directory)
            :documentation "Source type: File or directory"))
  (:documentation "Represents a single configuration entry."))

(defclass config-manager ()
  ((configs :initform () :accessor configs
            :documentation "List of config-object instances")
   (backup-on-overwrite :initarg :backup :initform t :accessor backup-on-overwrite-p
                        :documentation "Create backups before overwriting existing files"))
  (:documentation "Manages a collection of config-object entries."))


;;; Interface (Generic Functions)

(defgeneric add-config (manager name source place &key spec type validate)
  (:documentation "Add a config entry to the manager."))

(defgeneric remove-config (manager name-or-config)
  (:documentation "Remove a config entry by name or object."))

(defgeneric find-config (manager name)
  (:documentation "Find a config by name."))

(defgeneric list-configs (manager &optional stream)
  (:documentation "Print the deployment plan."))

(defgeneric deploy-configs (manager &optional verbose)
  (:documentation "Deploy all configurations."))

(defgeneric clear-configs (manager)
  (:documentation "Remove all config entries."))

(defgeneric config-count (manager)
  (:documentation "Return the number of configs."))


;;; Methods/Public API (Core Behavior)

(defmethod add-config ((manager config-manager) name source place
                       &key (spec :symlink) (type :file) (validate t))
  "Add a config entry with path expansion.
If VALIDATE is true (default), warns if source doesn't exist.
Replaces existing config with same name."
  (let ((expanded-source (expand-pathname source))
        (expanded-place (expand-pathname place)))
    ;; Validation
    (when validate
      (unless (or (u:file-exists-p expanded-source)
                  (ufs:directory-exists-p expanded-source))
        (warn 'source-not-found :path expanded-source)))
    ;; Remove existing with same name (avoid duplicates)
    (let ((existing (find-config manager name)))
      (when existing
        (setf (configs manager) (remove existing (configs manager)))))
    ;; Add new config
    (push (make-instance 'config-object
                         :name   name
                         :source expanded-source
                         :place  expanded-place
                         :spec   spec
                         :type   type)
          (configs manager)))
  manager)

(defun add-configs (mgr spec)
  "Add multiple config entries to MGR from SPEC.
SPEC is a list of entries, each shaped as add-config's own argument
list: (name source place &key spec type validate). Returns the names
of the configs added, in SPEC's order."
  (loop :for entry :in spec
        :do (apply #'add-config mgr entry)
        :collect (first entry)))

(defmethod remove-config ((manager config-manager) (name string))
  "Remove config by name."
  (let ((config (find-config manager name)))
    (when config
      (setf (configs manager) (remove config (configs manager))))
    config))

(defmethod remove-config ((manager config-manager) (config config-object))
  "Remove config object directly."
  (setf (configs manager) (remove config (configs manager)))
  config)

(defmethod find-config ((manager config-manager) (name string))
  "Find config by name (case-insensitive)."
  (find name (configs manager)
        :key #'config-name
        :test #'string-equal))

(defmethod config-count ((manager config-manager))
  "Return number of configs."
  (length (configs manager)))

(defmethod list-configs ((manager config-manager) &optional (stream t))
  (format stream "~A~A**** Config Deployment Outline ****~A~%~%"
          (color :bold) (color :green) (color :reset))
  (if (null (configs manager))
      (format stream "~A(no configurations defined)~A~%"
              (color :grey) (color :reset))
      (loop :for obj :in (reverse (configs manager))
            :for i :from 1
            :do (format stream "~A~D. ~A~A ~A~%"
                        (color :green) i
                        (color :grey) obj
                        (color :reset))))
  (values))

(defmethod deploy-configs ((manager config-manager) &optional (verbose t))
  "Deploy all configurations in MANAGER: symlink or copy as specified.

Actions are performed in reverse order of addition (LIFO).
If VERBOSE is true (default), prints a live summary with colors.

Returns a list of performed actions:
  ((:symlink \"/source\" \"/dest\" :success) ...)
  ((:copy \"/source\" \"/dest\" :success) ...)"
  (let ((results '())
        (count 0)
        (errors 0)
        (total (config-count manager)))
    (when (zerop total)
      (when verbose
        (format verbose "~%~A~ANo configurations to deploy.~A~%"
                (color :bold) (color :yellow) (color :reset)))
      (return-from deploy-configs nil))

    (when verbose
      (format verbose "~%~A~ADeploying Configuration ...~A~%~%"
              (color :bold) (color :green) (color :reset)))

    (dolist (obj (reverse (configs manager)))
      (incf count)
      (let ((src (config-source obj))
            (dst (config-place obj))
            (spec (config-spec obj))
            (type (config-type obj))
            (status :success)
            (error-msg nil)
            (do-backup (backup-on-overwrite-p manager)))

        (handler-case
            (progn
              ;; Ensure destination directory exists
              (ensure-directories-exist (directory-namestring dst))

              ;; Perform the deployment action
              (ecase spec
                (:symlink
                 (create-symlink src dst
                                 :dir (eq type :directory)
                                 :overwrite t
                                 :backup do-backup))
                (:copy
                 ;; Handle backup for copy operations
                 (when (and do-backup
                            (u:file-exists-p dst)
                            (not (symlinkp dst)))
                   (let ((backup (make-pathname
                                  :defaults dst
                                  :type (format nil "~A.bak"
                                                (or (pathname-type dst) "")))))
                     (ufs:rename-file-overwriting-target dst backup)))
                 ;; Remove existing symlink if destination is a symlink
                 (when (symlinkp dst)
                   (delete-file dst))
                 ;; Perform copy
                 (if (eq type :directory)
                     (copy-directory src dst :overwrite t)
                     (u:copy-file src dst)))))

          (error (e)
            (setf status :failed
                  error-msg (princ-to-string e))
            (incf errors)))

        (push (list spec src dst status error-msg) results)

        (when verbose
          (format verbose "~A[~A~D/~D~A] ~A~A ~A~A ~A~A~A~%"
                  (color :grey)
                  (if (eq status :success) (color :green) (color :red))
                  count total (color :grey)
                  (if (eq type :file) (color :yellow) (color :red))
                  src
                  (color :reset) (color :arrow)
                  (if (eq spec :symlink) (color :cyan) (color :yellow))
                  dst
                  (color :reset))
          (when error-msg
            (format verbose "~A    Error: ~A~A~%"
                    (color :red) error-msg (color :reset))))))

    (let ((actions (nreverse results)))
      (when verbose
        (format verbose "~%~A~ADeployment complete: ~A~D~A action~:P, ~A~D~A error~:P~A~%"
                (color :bold) (color :green)
                (color :cyan) (- (length actions) errors)
                (color :green)
                (color :red) errors (color :green)
                (color :reset))
        (when (plusp errors)
          (format verbose "~A~A~D action~:P failed.~A~%"
                  (color :bold) (color :red) errors (color :reset))))
      actions)))

(defmethod clear-configs ((manager config-manager))
  "Clear all config entries."
  (setf (configs manager) ())
  manager)

(defmethod print-object ((config config-object) stream)
  "Colorized pretty-print a CONFIG-OBJECT in #<> form for REPL and debugging."
  (write-string (color :grey) stream)
  (print-unreadable-object (config stream :type t)
    (format stream "~A~A ~A[~A~A ~A~A ~A~A~A] ~A~A ~A~A ~A~A ~A"
            (color :magenta) (config-name config)
            (color :reset)
            (color :yellow) (string-upcase (symbol-name (config-type config)))
            (color :reset) (color :arrow)
            (color :cyan) (string-upcase (symbol-name (config-spec config))) (color :reset)
            (color :yellow) (config-source config)
            (color :reset) (color :arrow)
            (color :cyan) (config-place config)
            (color :grey)))
  (write-string (color :reset) stream))


;;; Helper Functions/Macros/Utilities

(defun expand-pathname (pathspec)
  "Expand ~ and ~/ to user's home directory."
  (let* ((str (etypecase pathspec
                (string pathspec)
                (pathname (namestring pathspec))
                (symbol (symbol-name pathspec))))
         (home (namestring (user-homedir-pathname))))
    (u:ensure-pathname
     (cond
       ;; Bare ~ means home directory
       ((string= str "~")
        home)
       ;; ~/... expands to home + rest
       ((and (>= (length str) 2)
             (char= (char str 0) #\~)
             (char= (char str 1) #\/))
        (concatenate 'string home (subseq str 2)))
       ;; No expansion needed
       (t str)))))

(defun symlinkp (pathspec)
  "Test if path is a symlink."
  (eq (file-kind pathspec :follow-symlinks nil) :symbolic-link))

(defun symlink-target (pathspec)
  "Return the target of symlink PATHSPEC, or NIL if not a symlink.
Uses osicat:read-link internally."
  (when (symlinkp pathspec)
    (read-link pathspec)))

(defun symlink-update-needed-p (link target &key (dir nil))
  "Return T if LINK needs updating to point to TARGET.
Returns T if:
  - LINK doesn't exist
  - LINK exists but is not a symlink
  - LINK is a symlink but points to a different target

If DIR is true, treats TARGET as a directory path."
  (let ((expected-target (if dir (u:ensure-directory-pathname target) target)))
    (cond
      ;; Link doesn't exist - need to create
      ((not (or (u:file-exists-p link) (symlinkp link)))
       t)
      ;; Link exists but is not a symlink - need to replace
      ((not (symlinkp link))
       t)
      ;; Link is a symlink - check if target matches
      (t
       (let ((current-target (symlink-target link)))
         (not (equal (namestring expected-target)
                     (namestring current-target))))))))

(defun create-symlink (src link &key (dir nil) (overwrite t) (backup nil))
  "Create a symlink at LINK pointing to SRC.

Keywords:
  DIR - If true, treat SRC as a directory
  OVERWRITE - If true (default), replace existing file/symlink at LINK
  BACKUP - If true, backup existing file before overwriting (only for regular files)

Returns LINK pathname on success.
Signals an error if LINK exists and OVERWRITE is NIL."
  (let ((target (if dir (u:ensure-directory-pathname src) src)))
    ;; Handle existing file/symlink at link location
    (when (or (u:file-exists-p link) (symlinkp link))
      (unless overwrite
        (error "Link destination already exists: ~A" link))
      ;; Backup regular files if requested (symlinks just get replaced)
      (when (and backup (not (symlinkp link)))
        (let ((backup-path (make-pathname
                            :defaults link
                            :type (format nil "~A.bak"
                                          (or (pathname-type link) "")))))
          (ufs:rename-file-overwriting-target link backup-path)))
      ;; Remove existing symlink or file
      (when (symlinkp link)
        (delete-file link))
      (when (u:file-exists-p link)
        (delete-file link)))
    ;; Create the symlink
    (make-link link :target target)
    link))

(defun copy-directory (source dest &key (overwrite t))
  "Recursively copy directory SOURCE to DEST using pure Lisp.

Keywords:
  OVERWRITE - If true (default), overwrite existing files

Creates DEST if it doesn't exist. Copies all files and subdirectories."
  (let ((source-dir (u:ensure-directory-pathname source))
        (dest-dir (u:ensure-directory-pathname dest)))
    ;; Ensure destination exists
    (ensure-directories-exist dest-dir)

    ;; Copy all files in the source directory
    (dolist (file (u:directory-files source-dir))
      (let* ((filename (file-namestring file))
             (dest-file (merge-pathnames filename dest-dir)))
        (when (or overwrite (not (u:file-exists-p dest-file)))
          (u:copy-file file dest-file))))

    ;; Recursively copy subdirectories
    (dolist (subdir (u:subdirectories source-dir))
      (let* ((dirname (first (last (pathname-directory subdir))))
             (dest-subdir (merge-pathnames
                           (make-pathname :directory (list :relative dirname))
                           dest-dir)))
        (copy-directory subdir dest-subdir :overwrite overwrite)))

    dest-dir))
