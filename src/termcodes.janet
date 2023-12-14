(use ./utils)

(defmacro enable-cursor []
  '(prin "\e[?25h"))

(defmacro hide-cursor []
  '(prin "\e[?25l"))

(defmacro cursor-up [&opt n]
  (default n 1)
  ~(prin (string/format "\e[%dA" ,n)))

(defmacro cursor-down [&opt n]
  (default n 1)
  ~(prin (string/format "\e[%dB" ,n)))

(defmacro query-cursor-position []
  '(prin "\e[6n"))

(defmacro clear-line-forward []
  '(prin "\e[K"))

(defmacro clear-line-back []
  '(prin "\e[1K"))

(defmacro clear-line []
  '(prin "\e[2K"))