(uiop:define-package #:learn-cl/turing
  (:use #:cl)
  (:export )
  (:documentation "Turing Machine Examples in Common Lisp"))

(in-package #:learn-cl/turing)


;; Here is the classic proof by contradiction for the **Undecidability of the
;; Halting Problem in Common Lisp.
;;
;; Assume a hypothetical function `halts-p` exists. It takes a function and an
;; argument, returning `T` if the function halts, or `NIL` if it loops forever.


;; HYPOTHETICAL HALTING PREDICATE (Oracle)
;; (halts-p fn arg) -> returns T if (funcall fn arg) halts, NIL if it loops.
(declaim (ftype (function (function t) boolean) halts-p))

;; THE PARADOXICAL FUNCTION
(defun paradox (fn)
  "A function that does the opposite of what halts-p predicts for (fn fn)."
  (if (halts-p fn fn)
      (loop) ; Infinite loop if halts-p says it WILL halt
      t))    ; Halt immediately if halts-p says it WILL NOT halt

;; Now, pass #'paradox to itself:

(paradox #'paradox)

;; 1. If (halts-p #'paradox #'paradox) returns T (predicts it halts):
;;    `paradox' enters (loop) and runs forever.
;; 2. If (halts-p #'paradox #'paradox) returns NIL (predicts it loops forever):
;;    `paradox' evaluates the else branch and halts immediately returning `T`.



;; Both outcomes contradict the prediction of `halts-p'. Therefore, `halts-p'
;; cannot logically exist.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;
;; Using `declaim' (specifically with `ftype') allows us to declare the
;; hypothetical interface (type signature) of `halts-p' for the logical proof,
;; without needing to write a fake `defun' body.

;; 1. `declaim'
;; A global macro that makes a compiler declaration. It tells the Lisp
;; environment information about code *before* that code is actually defined or
;; run.
;;
;; 2. `ftype'
;; Short for "Function Type". This tells the compiler that the declaration
;; applies specifically to a function's signature (its inputs and output).
;;
;; 3. `halts-p'
;; The name of the function** whose signature we are declaring.
;;
;; 4. `(function (function t) boolean)'
;; This is the type signature itself, broken down as
;; (function (ARG-TYPES) RETURN-TYPE):
;;   - (function t) (The Arguments):
;;     -`function': The 1st argument must be a Lisp function.
;;     - `t': The 2nd argument can be anything (in Lisp, `t' is the supertype of
;;     all objects).
;; - `boolean' (The Return Value):
;;    - Specifies that `halts-p' will return either `T' or `NIL'.
