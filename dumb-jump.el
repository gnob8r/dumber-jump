;;; dumb-jump.el --- Dumb jumping to declarations

;; Copyright (C) 2015 jack angers
;; Author: jack angers
;; Version: 1.0
;; Package-Requires: ((json "1.2") (ht "2.0") (s "1.9.0") (dash "2.9.0") (cl-lib "0.5"))
;; Keywords: programming
;;; Commentary:

;; Uses `grep` to jump to delcartions via a list of regular expressions based on the major mode you are in.

;;; Code:
;; (require 'json)
;; (require 'url)
;; (require 'ht)
;; (require 's)
;; (require 'pp)
;; (require 'cl-lib)
(require 's)
(require 'dash)

(defun dumb-jump-asdf ()
  "asdf")

;; TODO: document defvars
(defvar dumb-jump-grep-prefix "LANG=C grep")

(defvar dumb-jump-grep-args "-REn")

;; todo: ensure
(defvar dumb-jump-find-rules '((:type "function" :language "elisp" :regex "\\\(defun\\s+JJJ\\s+")
                               (:type "variable" :language "elisp" :regex "\\\(defvar\\s+JJJ\\s+")
                               (:type "variable" :language "elisp" :regex "\\\(setq\\s+JJJ\\s+")))

(defvar dumb-jump-language-modes '((:language "elisp" :mode "emacs-lisp-mode")))


;; TODO: process response
(shell-command-to-string "grep -REn -e '\\(defun\s+' -e 'defvar ' .")

;; (let* ((cmd (dumb-jump-generate-command "emacs-lisp-mode" "blah")))
;;   (message cmd)
;;   (shell-command-to-string cmd))

;; TODO: ensure \s for regexes stay...
;; TODO: should take the path to search
;; TODO: should quote the regexes
(defun dumb-jump-generate-command (mode lookfor)
  (let* ((rules (dumb-jump-get-rules-by-mode mode))
         (regexes (-map (lambda (r) (plist-get r ':regex)) rules))
         (meat (s-join " -e " (-map (lambda (x) (s-replace "JJJ" lookfor x)) regexes))))
    (concat dumb-jump-grep-prefix " " dumb-jump-grep-args " " meat)))

(defun dumb-jump-get-rules-by-languages (languages)
  "Get a list of rules with a list of languages"
  (-mapcat (lambda (lang) (dumb-jump-get-rules-by-language lang)) languages))

(defun dumb-jump-get-rules-by-mode (mode)
  "Get a list of rules by a major mode"
  (dumb-jump-get-rules-by-languages (dumb-jump-get-languages-by-mode mode)))

(defun dumb-jump-get-rules-by-language (language)
  "Get list of rules for a language"
  (-filter (lambda (x) (string= (plist-get x ':language) language)) dumb-jump-find-rules))

(defun dumb-jump-get-modes-by-language (language)
  "Get all modes connected to a language"
  (-map (lambda (x) (plist-get x ':mode))
        (-filter (lambda (x) (string= (plist-get x ':language) language)) dumb-jump-language-modes)))

(defun dumb-jump-get-languages-by-mode (mode)
  "Get all languages connected to a mode"
  (-map (lambda (x) (plist-get x ':language))
        (-filter (lambda (x) (string= (plist-get x ':mode) mode)) dumb-jump-language-modes)))

;; for parsing a grep line
;;(-map (lambda (x) (s-split ":" x)) (s-split "\n" "a:1\nb:2\nc:c3"))


(provide 'dumb-jump)
;;; dumb-jump.el ends here
