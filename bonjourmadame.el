;;; bonjourmadame.el --- Say "Hello ma'am!"

;; Time-stamp: <2015-07-10 08:31:39>
;; Copyright (C) 2015 Pierre Lecocq
;; Version: 0.4

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Display the image from bonjourmadame.fr
;; Updated every day at 10AM (on Europe/Paris timezone)
;;
;; Keys:
;;
;; - n: get the next image
;; - p: get the previous image
;; - h: hide the buffer (switch to the previous one)
;; - q: quit (kill the buffer)

;;;; Changelog:

;; v0.4: display and time bug fixes
;; v0.3: add page navigation
;; v0.2: make it a major mode
;; v0.1: first release

;;; Code:

(defvar bonjourmadame--cache-dir "~/.bonjourmadame")
(defvar bonjourmadame--buffer-name "*Bonjour Madame*")
(defvar bonjourmadame--base-url "http://bonjourmadame.fr")
(defvar bonjourmadame--refresh-hour 10)
(defvar bonjourmadame--regexp "<img\\(.\\)+src=\"\\(http://\\(.\\)+tumblr.com\\(.\\)+.\\(png\\|jpg\\|jpeg\\|gif\\)\\)+\"[^>]+>")
(defvar bonjourmadame--image-time nil)
(defvar bonjourmadame--image-url "")
(defvar bonjourmadame--previous-buffer nil)
(defvar bonjourmadame--page 1)

(define-derived-mode bonjourmadame-mode special-mode "bonjourmadame"
  "Say Hello ma'am!"
  :group 'bonjourmadame)

(define-key bonjourmadame-mode-map (kbd "n") 'bonjourmadame-next)
(define-key bonjourmadame-mode-map (kbd "p") 'bonjourmadame-prev)
(define-key bonjourmadame-mode-map (kbd "h") 'bonjourmadame-hide)
(define-key bonjourmadame-mode-map (kbd "q") 'bonjourmadame-quit)

(defun bonjourmadame--get-image-url ()
  "Get the image URL."
  (let ((url (concat bonjourmadame--base-url "/page/" (number-to-string bonjourmadame--page))))
    (with-current-buffer (url-retrieve-synchronously url)
      (goto-char (point-min))
      (re-search-forward bonjourmadame--regexp nil t)
      (setq bonjourmadame--image-url (match-string 2))
      (kill-buffer)))
  bonjourmadame--image-url)

(defun bonjourmadame--get-image-path ()
  "Get the local image path."
  (set-time-zone-rule "Europe/Paris")
  (setq bonjourmadame--image-time (current-time))
  (when (> bonjourmadame--page 1)
    (setq bonjourmadame--image-time (time-subtract bonjourmadame--image-time (seconds-to-time (* (- bonjourmadame--page 1) 60 60 24)))))
  (let ((current-hour (string-to-number (format-time-string "%H"))))
    (when (< current-hour bonjourmadame--refresh-hour)
      (message "Wait at most %dh to get a newer image!" (- bonjourmadame--refresh-hour current-hour))
      (setq bonjourmadame--image-time (time-subtract bonjourmadame--image-time (seconds-to-time (* bonjourmadame--refresh-hour 60 60))))))
  (concat
   (file-name-as-directory bonjourmadame--cache-dir)
   (format "%s.png" (format-time-string "%Y-%m-%d" bonjourmadame--image-time))))

(defun bonjourmadame--download-image ()
  "Download and store the image."
  (unless (file-accessible-directory-p bonjourmadame--cache-dir)
    (make-directory bonjourmadame--cache-dir t))
  (let ((path (bonjourmadame--get-image-path)))
    (unless (file-exists-p path)
      (url-copy-file (bonjourmadame--get-image-url) path))))

(defun bonjourmadame--display-image ()
  "Display the image."
  (unless (display-graphic-p)
    (error "bonjourmadame is only available in graphical mode. You might want to execute `bonjourmadame-browse' instead."))
  (bonjourmadame--download-image)
  (let ((image (create-image (bonjourmadame--get-image-path)))
        (buf (current-buffer)))
    (when (not (equal (buffer-name buf) bonjourmadame--buffer-name))
      (setq bonjourmadame--previous-buffer buf))
    (switch-to-buffer bonjourmadame--buffer-name)
    (when buffer-read-only
      (setq inhibit-read-only t))
    (erase-buffer)
    (insert-image image)
    (insert (format "\n\nDate: %s" (format-time-string "%Y-%m-%d" bonjourmadame--image-time)))
    (bonjourmadame-mode)
    (read-only-mode)
    (goto-char (point-min))))

(defun bonjourmadame-next ()
  "Display the next image."
  (interactive)
  (setq bonjourmadame--page (+ bonjourmadame--page 1))
  (bonjourmadame--display-image))

(defun bonjourmadame-prev ()
  "Display the previous image."
  (interactive)
  (when (> bonjourmadame--page 1)
    (setq bonjourmadame--page (- bonjourmadame--page 1))
    (bonjourmadame--display-image)))

(defun bonjourmadame-hide ()
  "Hide the buffer."
  (interactive)
  (switch-to-buffer bonjourmadame--previous-buffer))

(defun bonjourmadame-quit ()
  "Quit."
  (interactive)
  (setq bonjourmadame--page 1)
  (setq bonjourmadame--image-time nil)
  (setq bonjourmadame--image-url "")
  (kill-buffer (get-buffer bonjourmadame--buffer-name))
  (switch-to-buffer bonjourmadame--previous-buffer)
  (message "Au revoir madame"))

;;;###autoload
(defun bonjourmadame-browse ()
  "Browse to the site."
  (interactive)
  (browse-url bonjourmadame--base-url))

;;;###autoload
(defun bonjourmadame ()
  "Say Hello ma'am!"
  (interactive)
  (bonjourmadame--display-image))

(provide 'bonjourmadame)

;;; bonjourmadame.el ends here
