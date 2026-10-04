(uiop:define-package :sojrn/base/database
  (:use :cl :sojrn/base/config-manager)
  (:import-from :uiop/filesystem
                #:ensure-all-directories-exist)
  (:import-from :uiop/configuration
                #:xdg-data-home)
  (:import-from :uiop/os
                #:getenv)
  (:local-nicknames (#:u #:uiop)
                    (#:db #:dbi))
  ;; Database management
  (:export #:with-database
           #:initialize-database)
  ;; Deployment records
  (:export #:record-deployment
           #:get-deployment-history
           #:get-deployment-by-id
           #:get-latest-deployment)
  ;; Config snapshots
  (:export #:save-config-snapshot
           #:load-config-snapshot
           #:list-snapshots)
  ;; Rollback
  (:export #:rollback-deployment)
  ;; Integration
  (:export #:deploy-with-history)
  (:documentation "SQLite persistence for config-manager deployments.

This module provides:
  - Deployment history tracking
  - Configuration snapshots
  - Rollback capability

Requires: cl-dbi (SQLite3 backend)
"))
(in-package :sojrn/base/database)


;;;  Database Configuration

(defparameter *db-connection* nil
  "Current database connection (dynamically bound).")


;;; Schema Definition

(defparameter *schema*
  '("CREATE TABLE IF NOT EXISTS deployments (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       timestamp TEXT NOT NULL DEFAULT (datetime('now')),
       hostname TEXT,
       username TEXT,
       status TEXT NOT NULL DEFAULT 'pending',
       notes TEXT
     )"

    "CREATE TABLE IF NOT EXISTS deployment_actions (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       deployment_id INTEGER NOT NULL,
       config_name TEXT NOT NULL,
       source_path TEXT NOT NULL,
       dest_path TEXT NOT NULL,
       spec TEXT NOT NULL,
       type TEXT NOT NULL,
       status TEXT NOT NULL DEFAULT 'pending',
       error_message TEXT,
       FOREIGN KEY (deployment_id) REFERENCES deployments(id)
     )"

    "CREATE TABLE IF NOT EXISTS config_snapshots (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       name TEXT NOT NULL,
       created_at TEXT NOT NULL DEFAULT (datetime('now')),
       description TEXT
     )"

    "CREATE TABLE IF NOT EXISTS snapshot_configs (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       snapshot_id INTEGER NOT NULL,
       config_name TEXT NOT NULL,
       source_path TEXT NOT NULL,
       dest_path TEXT NOT NULL,
       spec TEXT NOT NULL,
       type TEXT NOT NULL,
       FOREIGN KEY (snapshot_id) REFERENCES config_snapshots(id)
     )"

    "CREATE INDEX IF NOT EXISTS idx_deployment_timestamp
       ON deployments(timestamp DESC)"

    "CREATE INDEX IF NOT EXISTS idx_actions_deployment
       ON deployment_actions(deployment_id)")
  "SQL statements to initialize the database schema.")


;;; Database Connection Management

(defmacro with-database ((path) &body body)
  "Execute BODY with a database connection bound to *db-connection*.
Automatically handles connection opening and closing. PATH is required."
  `(db:with-connection (*db-connection*
                        :sqlite3
                        :database-name (u:native-namestring ,path))
     ,@body))

(defun initialize-database (path)
  "Initialize the database with the required schema."
  (with-database (path)
    (dolist (statement *schema*)
      (db:do-sql *db-connection* statement))
    (format t "~%Database initialized at: ~A~%~%" path)
    (format nil "Database initialized at: ~A~%" path)))


;;; Deployment Recording

(defun record-deployment (manager &key notes)
  "Record a new deployment from MANAGER, returning the deployment ID.
Call this BEFORE deploy-configs to create the deployment record,
then update action statuses as deployment proceeds."
  (let ((deployment-id
          (db:do-sql *db-connection*
            "INSERT INTO deployments (hostname, username, notes) VALUES (?, ?, ?)"
            (list (machine-instance)
                  (getenv "USER")
                  notes))))
    ;; Record each config as a pending action
    (dolist (config (configs manager))
      (db:do-sql *db-connection*
        "INSERT INTO deployment_actions
           (deployment_id, config_name, source_path, dest_path, spec, type)
         VALUES (?, ?, ?, ?, ?, ?)"
        (list deployment-id
              (config-name config)
              (namestring (config-source config))
              (namestring (config-place config))
              (symbol-name (config-spec config))
              (symbol-name (config-type config)))))
    deployment-id))

(defun update-action-status (action-id status &optional error-message)
  "Update the status of a deployment action."
  (db:do-sql *db-connection*
    "UPDATE deployment_actions SET status = ?, error_message = ? WHERE id = ?"
    (list status error-message action-id)))

(defun complete-deployment (deployment-id status)
  "Mark a deployment as complete with final STATUS."
  (db:do-sql *db-connection*
    "UPDATE deployments SET status = ? WHERE id = ?"
    (list status deployment-id)))


;;; History Queries

(defun get-deployment-history (&key (limit 20) (offset 0))
  "Get recent deployment history."
  (db:fetch-all
   (db:execute
    (db:prepare *db-connection*
                "SELECT id, timestamp, hostname, username, status, notes
       FROM deployments
       ORDER BY timestamp DESC
       LIMIT ? OFFSET ?")
    (list limit offset))))

(defun get-deployment-by-id (deployment-id)
  "Get a deployment record with all its actions."
  (let ((deployment
          (db:fetch
           (db:execute
            (db:prepare *db-connection*
                        "SELECT * FROM deployments WHERE id = ?")
            (list deployment-id))))
        (actions
          (db:fetch-all
           (db:execute
            (db:prepare *db-connection*
                        "SELECT * FROM deployment_actions WHERE deployment_id = ?")
            (list deployment-id)))))
    (when deployment
      (list :deployment deployment
            :actions actions))))

(defun get-latest-deployment ()
  "Get the most recent deployment."
  (let ((row (db:fetch
              (db:execute
               (db:prepare *db-connection*
                           "SELECT id FROM deployments ORDER BY timestamp DESC LIMIT 1")))))
    (when row
      (get-deployment-by-id (getf row :|id|)))))


;;; Configuration Snapshots

(defun save-config-snapshot (manager name &key description)
  "Save current manager configuration as a named snapshot."
  (let ((snapshot-id
          (db:do-sql *db-connection*
            "INSERT INTO config_snapshots (name, description) VALUES (?, ?)"
            (list name description))))
    (dolist (config (configs manager))
      (db:do-sql *db-connection*
        "INSERT INTO snapshot_configs
           (snapshot_id, config_name, source_path, dest_path, spec, type)
         VALUES (?, ?, ?, ?, ?, ?)"
        (list snapshot-id
              (config-name config)
              (namestring (config-source config))
              (namestring (config-place config))
              (symbol-name (config-spec config))
              (symbol-name (config-type config)))))
    snapshot-id))

(defun load-config-snapshot (manager snapshot-id)
  "Load a snapshot into MANAGER, replacing current configs."
  (clear-configs manager)
  (let ((rows (db:fetch-all
               (db:execute
                (db:prepare *db-connection*
                            "SELECT * FROM snapshot_configs WHERE snapshot_id = ?")
                (list snapshot-id)))))
    (dolist (row rows)
      (add-config manager
                  (getf row :|config_name|)
                  (getf row :|source_path|)
                  (getf row :|dest_path|)
                  :spec (intern (getf row :|spec|) :keyword)
                  :type (intern (getf row :|type|) :keyword))))
  manager)

(defun list-snapshots (&key (limit 50))
  "List available configuration snapshots."
  (db:fetch-all
   (db:execute
    (db:prepare *db-connection*
                "SELECT id, name, created_at, description
       FROM config_snapshots
       ORDER BY created_at DESC
       LIMIT ?")
    (list limit))))


;;; Rollback Support

(defun rollback-deployment (deployment-id &key dry-run)
  "Attempt to rollback a deployment by reversing its actions.
For symlinks: remove the symlink
For copies: remove the copied file (original source still exists)

If DRY-RUN is true, only report what would be done."
  (let ((deployment (get-deployment-by-id deployment-id)))
    (unless deployment
      (error "Deployment ~A not found" deployment-id))

    (let ((actions (getf deployment :actions))
          (rolled-back 0))
      (dolist (action (reverse actions))
        (let ((dest (getf action :|dest_path|))
              (spec (getf action :|spec|)))
          (declare (ignore spec))
          (when (probe-file dest)
            (if dry-run
                (format t "Would remove: ~A~%" dest)
                (progn
                  (delete-file dest)
                  (incf rolled-back))))))

      (unless dry-run
        (db:do-sql *db-connection*
          "UPDATE deployments SET status = 'rolled_back' WHERE id = ?"
          (list deployment-id)))

      (values rolled-back (length actions)))))


;;; Integration with config-manager

(defun deploy-with-history (manager &key notes verbose)
  "Deploy configurations and record in database.
Returns (values deployment-id results)."
  (let ((deployment-id (record-deployment manager :notes notes)))
    (handler-case
        (progn
          (deploy-configs manager verbose)
          (complete-deployment deployment-id "success")
          (values deployment-id "success"))
      (error (e)
        (complete-deployment deployment-id "failed")
        (values deployment-id (format nil "failed: ~A" e))))))
