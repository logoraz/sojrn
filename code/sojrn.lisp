(uiop:define-package :sojrn
  (:use :cl)
  (:import-from :sojrn/startup
                #:*user-sojrn-directory*
                #:*sojrn-cache-directory*
                #:*sojrn-db-status*
                #:*user-config-loaded*
                #:*config-spec*
                #:*config-mgr*)
  (:use-reexport :sojrn/persistence
                 :sojrn/ui/app)
  ;; Setup
  (:export #:*config-mgr*
           #:*config-spec*
           #:*user-sojrn-directory*
           #:*sojrn-cache-directory*
           #:*sojrn-db-status*
           #:*user-config-loaded*
           #:outline
           #:deploy)
  ;; Main Entry
  (:export #:main)
  (:documentation "Main package of SOJRN"))

(in-package :sojrn)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Helpers & Conveneience Wrappers


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Entry Point

(defun main ()
  "Main entry point for the executable."
  (sojrn-app))
