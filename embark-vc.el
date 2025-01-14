;;; embark-vc.el --- Embark actions for various VC integrations -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2021 Ellis Kenyő
;;
;; Author: Ellis Kenyő <https://github.com/elken>
;; Maintainer: Ellis Kenyő <me@elken.dev>
;; Created: November 20, 2021
;; Modified: November 20, 2021
;; Version: 0.2
;; Keywords: convenience matching terminals tools unix vc
;; Homepage: https://github.com/elken/embark-vc
;; Package-Requires: ((emacs "26.1") (code-review "0.0.2") (embark "0.13") (forge "0.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; Some actions and conveniences for interacting with various vc-related
;; packages
;;
;;; Code:

(require 'embark)
(require 'forge-commands)
(require 'code-review)
(require 's)

(defun embark-vc-target-topic-at-point ()
  "Target a Topic in the context of Magit."
  (when (derived-mode-p 'magit-mode)
    (when-let ((topic (forge-topic-at-point)))
      (if (forge-issue-at-point)
          `(issue ,(oref topic number))
        `(pull-request ,(oref topic number))))))

(defun embark-vc-target-commit-at-point ()
  "Target a Commit in the context of Magit."
  (when (derived-mode-p 'magit-mode)
    (save-excursion
      (move-to-left-margin)
      (when (get-text-property (point) 'font-lock-face)
        (let* ((beg (progn (skip-chars-backward "\\b[0-9a-f]\\{5,40\\}\\b") (point)))
               (end (progn (skip-chars-forward "\\b[0-9a-f]\\{5,40\\}\\b") (point)))
               (str (buffer-substring-no-properties beg end)))
          (save-match-data
            (when (string-match "\\b[0-9a-f]\\{5,40\\}\\b" str)
              `(commit ,str))))))))

(defun embark-vc-target-conflict-at-point ()
  "Target a Merge Conflict at point."
  (when (or (derived-mode-p 'magit-mode)
            smerge-mode)
    (when-let* ((beg (save-excursion (when (search-backward "<<<<<<<" nil t)
                                       (move-to-left-margin)
                                       (point))))
                (end (save-excursion (when (search-forward ">>>>>>>" nil t)
                                       (move-end-of-line nil)
                                       (point))))
                (str (buffer-substring-no-properties beg end)))
      (save-match-data
        (when (string-match "<<<<<<<.*?=======.*?>>>>>>>" (s-replace "\n" "" str))
          `(conflict "test" ,beg . ,end))))))

(defun embark-vc-id-to-topic (id)
  "Convert a given ID to a topic."
  (when-let ((pr (forge-get-topic (if (stringp id) (string-to-number id) id))))
    pr))

(defun embark-vc-get-topic-title (topic)
  "Get the title for a TOPIC."
  (oref topic title))

(defun embark-vc-id-to-url (id)
  "Convert a given ID to a topic url scoped to the current forge."
  (when-let ((url (forge-get-url (embark-vc-id-to-topic id))))
    url))

(defun embark-vc-edit-topic-title (id)
  "Edit the title for a topic by ID."
  (when-let ((pr (embark-vc-id-to-topic id)))
    (forge-edit-topic-title pr)))

(defun embark-vc-edit-topic-state (id)
  "Edit the title for a topic by ID."
  (when-let ((topic (embark-vc-id-to-topic id)))
    (when (magit-y-or-n-p
           (format "%s %S"
                   (cl-ecase (oref topic state)
                     (merged (error "Merged pull-requests cannot be reopened"))
                     (closed "Reopen")
                     (open   "Close"))
                   (embark-vc-get-topic-title topic)))
      (forge-edit-topic-state topic))))

(defun embark-vc-edit-topic-labels (id)
  "Edit the title for a topic by ID."
  (when-let ((pr (embark-vc-id-to-topic id)))
    (forge-edit-topic-labels pr)))

(defun embark-vc-start-review (id)
  "Start a review for a topic by ID."
  (when-let ((pr (embark-vc-id-to-url id)))
    (code-review-start pr)))

(defun embark-vc-checkout-branch (id)
  (when-let ((pr (embark-vc-id-to-topic id)))
    (forge-checkout-pullreq pr)))

(embark-define-keymap embark-vc-topic-map
  "Keymap for actions related to Topics"
  ("y" forge-copy-url-at-point-as-kill)
  ("s" embark-vc-edit-topic-state)
  ("t" embark-vc-edit-topic-title)
  ("l" embark-vc-edit-topic-labels))

(embark-define-keymap embark-vc-pull-request-map
  "Keymap for actions related to Pull Requests"
  :parent embark-vc-topic-map
  ("b" embark-vc-checkout-branch)
  ("r" embark-vc-start-review)
  ("m" forge-merge))

(embark-define-keymap embark-vc-issue-map
  "Keymap for actions related to Issues"
  :parent embark-vc-topic-map)

(embark-define-keymap embark-vc-commit-map
  "Keymap for actions related to Commits"
  ("b" forge-browse-commit))

(embark-define-keymap embark-vc-conflict-map
  "Keymap for actions related to Merge Conflicts"
  ("t" smerge-keep-upper)
  ("b" smerge-keep-lower)
  ("a" smerge-keep-all)
  ("d" smerge-ediff))

(add-to-list 'embark-keymap-alist '(pull-request . embark-vc-pull-request-map))
(add-to-list 'embark-keymap-alist '(issue . embark-vc-issue-map))
(add-to-list 'embark-keymap-alist '(commit . embark-vc-commit-map))
(add-to-list 'embark-keymap-alist '(conflict . embark-vc-conflict-map))

(add-to-list 'embark-target-finders 'embark-vc-target-topic-at-point)
(add-to-list 'embark-target-finders 'embark-vc-target-commit-at-point)
(add-to-list 'embark-target-finders 'embark-vc-target-conflict-at-point)

(provide 'embark-vc)
;;; embark-vc.el ends here
