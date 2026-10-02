(uiop:define-package :sojrn/lib/ansi-color
  (:use :cl
        :sojrn/lib/syntax
        :trivial-gray-streams)
  (:import-from :cl-ppcre
                #:regex-replace-all)
  ;; Class/Methods
  (:export #:colored-stream
           #:target
           #:use-colors
           #:use-colors-p)
  ;; ANSI parameters/functions
  (:export #:*use-unicode-arrows*
           #:color
           #:arrow
           #:strip-ansi)
  (:documentation "ANSI Color support for CLI."))

(in-package :sojrn/lib/ansi-color)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; ANSI Color Support

(defparameter *esc* (string (code-char 27))
  "ANSI escape character as a string.")

(defparameter *color-codes*
  `((:reset   . ,(concat *esc* "[0m"))
    (:bold    . ,(concat *esc* "[1m"))
    (:red     . ,(concat *esc* "[31m"))
    (:green   . ,(concat *esc* "[32m"))
    (:yellow  . ,(concat *esc* "[33m"))
    (:blue    . ,(concat *esc* "[34m"))
    (:magenta . ,(concat *esc* "[35m"))
    (:cyan    . ,(concat *esc* "[36m"))
    (:grey    . ,(concat *esc* "[90m"))
    (:arrow   . " → "))
  "Direct keyword → ANSI escape code")

(defparameter *use-unicode-arrows* t
  "Use Unicode arrows (→) when T and terminal supports it.")

(defun color (&rest commands)
  "Return concatenated ANSI codes for COMMANDS."
  (apply #'concatenate 'string
         (mapcar (lambda (c) (or (cdr (assoc c *color-codes*)) "")) commands)))

(defun arrow ()
  "Return arrow string based on Unicode support."
  (if *use-unicode-arrows* (color :arrow) " -> "))

(defun strip-ansi (s)
  "Remove ANSI escape codes from string S."
  (regex-replace-all "\\[[0-9;]*m" s ""))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Modified Stream Class & Methods

(defclass colored-stream (trivial-gray-streams:fundamental-character-output-stream)
  ((target :initarg :target :reader target)
   (use-colors :initarg :use-colors :initform t :accessor use-colors-p))
  (:documentation "A Gray stream that adds ANSI colors to output."))

(defmethod trivial-gray-streams:stream-write-string
    ((stream colored-stream) string &optional start end)
  "Write STRING to target, stripping ANSI codes if colors disabled."
  (with-slots (target use-colors) stream
    (write-string (if use-colors string (strip-ansi string))
                  target :start (or start 0) :end end)))

(defmethod trivial-gray-streams:stream-write-char ((stream colored-stream) char)
  "Fallback: write single character directly."
  (write-char char (target stream)))

