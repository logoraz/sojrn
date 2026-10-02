(uiop:define-package :sojrn/ui/app
  (:use :cl)
  (:import-from :gtk
                #:application
                #:application-window
                #:box
                #:button
                #:window-close
                #:box-append
                #:window-child
                #:widget-visible)
  (:import-from :gobject
                #:signal-connect)
  (:import-from :gio
                #:application-run)
  (:export #:sojrn-app)
  (:documentation "Main renderer application package."))

(in-package :sojrn/ui/app)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Define GTK4 Application

(defun sojrn-app ()
  "Create and run a minimal GTK4 application window with a close button."
  (let ((app (make-instance 'application
                             :application-id "org.sojrn.app"
                             :flags 0)))
    (signal-connect app "activate"
      (lambda (application)
        (let* ((window (make-instance 'application-window
                                       :application application
                                       :title "sojrn"
                                       :default-width 400
                                       :default-height 300))
               (box (make-instance 'box
                                    :orientation :vertical
                                    :spacing 6
                                    :margin-top 12
                                    :margin-bottom 12
                                    :margin-start 12
                                    :margin-end 12))
               (close-button (make-instance 'button :label "Close")))
          (signal-connect close-button "clicked"
            (lambda (button)
              (declare (ignore button))
              (window-close window)))
          (box-append box close-button)
          (setf (window-child window) box)
          (setf (widget-visible window) t))))
    (application-run app nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Public API

