(defpackage #:learn-cl/scalc
  (:use #:cl)
  (:export #:make-calculator
           #:add
           #:subtract
           #:multiply
           #:divide
           #:clear)
  (:documentation "A CLOS calculator example"))
(in-package #:learn-cl/scalc)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; CLOS Calculator Definition

(defclass calculator ()
  ((value
    :initarg :value
    :initform 0
    :accessor value
    :documentation "Calculator value"))
  (:documentation "The base of all calculators"))

(defun make-calculator (value)
  "Constructor to define a calculator instance."
  (make-instance 'calculator :value value))

(defvar *my-calc* (make-calculator 0))


;;; Define the interface - Generic Functions
(defgeneric add (calculator x)
  (:documentation
   "Simple addition, adding X to calculator value."))

(defgeneric subtract (calculator x)
  (:documentation
   "Simple subtraction, subtracting X from calculator value."))

(defgeneric multiply (calculator x)
  (:documentation
   "Simple mulitplication, multiplying X by calculator value."))

(defgeneric divide (calculator x)
  (:documentation
   "Simple division, dividing X by calculator value."))

(defgeneric clear (calculator)
  (:documentation
   "Clear calculator value."))


;;; Define the implementation - Methods
(defmethod add ((c calculator) x)
  (setf (value c) (+ (value c) x)))

(defmethod subtract ((c calculator) x)
  (setf (value c) (- (value c) x)))

(defmethod multiply ((c calculator) x)
  (setf (value c) (* (value c) x)))

(defmethod divide ((c calculator) x)
  (if (not (eq (value c) 0))
      (setf (value c) (/ (value c) x))
    (format nil "Cannot divide by 0.")))

(defmethod clear ((c calculator))
  (setf (value c) 0))
