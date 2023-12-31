###
### A Janet implementation of `(getline)` that is non-blocking.
### Allows for beter integration in netrepl (completions and docs can be streamed
### over the network).
###

### TODO
# - unit testing?

(import spork/rawterm)
(import ./color :as c)

(def max-history "Maximal amount of items in the history" 500)

(def- sym-prefix-peg
  (peg/compile
    ~{:symchar (+ (range "\x80\xff" "AZ" "az" "09") (set "!$%&*+-./:<?=>@^_"))
      :anchor (drop (cmt ($) ,|(= $ 0)))
      :cap (* (+ (> -1 (not :symchar)) :anchor) (* ($) '(some :symchar)))
      :recur (+ :cap (> -1 :recur))
      :main (> -1 :recur)}))

(defn default-autocomplete-context
  "Given a buffer and a cursor position, extract a string that will be used as context for autocompletion.
  Return a position and substring from the buffer to use for autocompletion."
  [buf pos]
  (peg/match sym-prefix-peg buf pos))

(defn- greatest-common-prefix
  "Find the greatest common prefix for autocompletion"
  [a b]
  (if (> (length a) (length b))
    (greatest-common-prefix b a)
    (slice a 0 (length (take-until |(not $) (map = a b))))))

(defn default-doc-fetch
  "Default handler for Ctrl-G to lookup docstrings in the current environment."
  [sym w &]
  (def doc-entry (get root-env (symbol sym)))
  (when doc-entry
    (def doc-string (get doc-entry :doc))
    (when doc-string
      (string "\n" (doc-format doc-string w 4 true)))))

(defn default-autocomplete-options
  "Default handler to get available autocomplete options for a given substring."
  [prefix &]
  (def seen @{})
  (def ret @[])
  (var env (curenv))
  (while env
    (eachk symname env
      (when (not (seen symname))
        (when (symbol? symname)
          (when (string/has-prefix? prefix symname)
            (put seen symname true)
            (array/push ret symname)))))
    (set env (table/getproto env)))
  (sort ret)
  ret)

(comment
  (def autocomplete-options filepath-autocomplete)
  (def buf @".")
  (var pos 1)
  )

(defn make-getline
  "Reads a line of input into a buffer, like `getline`. However, allow looking up entries with a general
  lookup function rather than a environment table."
  [&opt autocomplete-context autocomplete-options doc-fetch private]

  (default autocomplete-context default-autocomplete-context)
  (default autocomplete-options default-autocomplete-options)
  (default doc-fetch default-doc-fetch)

  # state
  (var w "last measured terminal width (columns)" 0)
  (var h "last measured height (rows)" 0)
  (var buf "line buffer" @"")
  (var prpt "prompt string (line prefix)" "")
  (var prpt-width "prompt string character width" 0)
  (def history "history stack. Top item is current placeholder." @[])
  (def tmp-buf "Buffer to group writes to stderr for terminal rendering." @"")
  (var pos "Cursor byte position in buf. Must be on valid utf-8 start byte at all times." 0)
  (var lines-below "Number of dirty lines below input line for drawing cleanup." 0)
  (var offset "Lines scrolled by prints to account for if interview is cancelled" 0)
  (var ret-value "Value to return to caller, usually the mutated buffer." buf)
  (var more-input "Loop condition variable" true)
  (var active-autosuggestions nil)
  (var autosuggestion-selected nil)
  (var input-buf @"") 

  (defn getc
    "Get next character. Caller needs to check input buf after call if utf8 sequence returned (>= c 0x80)"
    []
    (buffer/clear input-buf)
    (rawterm/getch input-buf)
    (def c (get input-buf 0))
    (when (>= c 0x80)
      (repeat (cond
                (= (band c 0xF8) 0xF0) 3
                (= (band c 0xF0) 0xE0) 2
                1)
        (rawterm/getch input-buf)))
    c)

  (defn- flushs
    []
    (eprin "\e[38;2;97;214;214m" tmp-buf "\e[0;39m")
    (eflush)
    (buffer/clear tmp-buf))

  (defn- clear
    []
    (eprin "\e[H\e[2J")
    (eflush))

  (defn- clear-lines
    []
    (repeat lines-below
      (buffer/push tmp-buf "\e[1B\e[999D\e[K"))
    (when (pos? lines-below)
      (buffer/format tmp-buf "\e[%dA\e[999D" lines-below) 
      (set lines-below 0))
    (flushs))

  (defn- refresh
    []
    (def available-w (- w prpt-width))
    (def at-end (= pos (length buf)))
    (def next-pos (rawterm/buffer-traverse buf pos 1 true))
    (def width-under-cursor (if at-end 1 (rawterm/monowidth buf pos next-pos)))
    (var columns-to-pos (+ width-under-cursor (rawterm/monowidth buf 0 pos)))
    (def shift-right-amnt (max 0 (- columns-to-pos available-w)))

    # Strange logic to handle the case when the windowing code would cut a character in half.
    (def test-buf (rawterm/slice-monowidth buf shift-right-amnt))
    (def add-space-padding (not= shift-right-amnt (rawterm/monowidth test-buf)))
    (def view-pos
      (if add-space-padding
        (rawterm/buffer-traverse buf (length test-buf) 1 true)
        (length test-buf)))
    (def pad (if add-space-padding " " ""))

    (def view (let [tv (rawterm/slice-monowidth buf available-w view-pos)]
                (if private (string/repeat "*" (length tv)) tv)))
    (def visual-pos (+ prpt-width (- columns-to-pos shift-right-amnt width-under-cursor)))
    (comment eprin (string/format "\e[1A%d\e[%dD\e[1B" prpt-width (length (string visual-pos))))
    (buffer/format tmp-buf "\r%s%s\e[38;2;97;214;214m%s\e[0;39m\e[0K\r\e[%dC" prpt pad view visual-pos)
    (flushs))

  (defn- check-overflow
    []
    (def available-w (- w prpt-width))
    (- (rawterm/monowidth buf) available-w))

  (defn- insert
    [bytes &opt draw]
    (buffer/push buf bytes)
    (def old-pos pos)
    (+= pos (length bytes))
    (if (= (length buf) pos)
      (do
        (when draw
          (def o (check-overflow))
          (if (>= o 0)
            (refresh)
            (do
              (buffer/push tmp-buf
                           (if private
                             (string/repeat "*" (length bytes))
                             bytes))
              (flushs)))))
      (do
        (buffer/blit buf buf pos old-pos -1)
        (buffer/blit buf bytes old-pos)
        (buffer/popn buf (length bytes))
        (if draw (refresh)))))

  (defn- autocomplete
    []
    (unless autocomplete-options (break))
    (var ctx (or (autocomplete-context buf pos) [0 ""]))
    (def [ctx-pos ctx-string] ctx)
    (set pos (+ ctx-pos (length ctx-string)))
    (def options (autocomplete-options ctx-string buf pos))
    (clear-lines)
    # TODO: Selecting an suggestion with tab/arrow keys and confirming with enter
    # (when (deep= options active-autosuggestions)
    #   (if autosuggestion-selected
    #     (+= autosuggestion-selected 1)
    #     (set autosuggestion-selected 0)))
    # (when autosuggestion-selected
    #   (update options autosuggestion-selected |(c/cformat $ {:color :black :background :white})))
    (case (length options)
      0 (refresh)
      1
      (do
        (def choice (get options 0))
        (insert (string/slice choice (length ctx-string)))
        (refresh))
      (do # print all options
        (def gcp (reduce greatest-common-prefix (first options) options))
        (insert (string/slice gcp (length ctx-string)))

        (def maxlen (extreme > (map length options)))
        (def colwidth (+ 4 maxlen))
        (def cols (max 1 (math/floor (/ w colwidth))))
        (def rows (partition cols options))
        (def padding (string/repeat " " colwidth))
        (set lines-below (length rows))
        (var i 0)
        (each row rows
          (eprint) # TODO: Determine whether the terminal will scroll here and if so increment offset
          (each item row 
            (+= i 1)
            # (when (= i autosuggestion-selected) (eprin "\e[0;30m\e[0;47m"))
            (eprin (slice (string item padding) 0 colwidth))
            # (when (= i autosuggestion-selected (eprin "\e[0;39m\e[0;49m")))
            ))
        (eprinf "\e[%dA" lines-below)
        (eflush)

        # (set active-autosuggestions options)

        (refresh))))

  (defn- kleft
    [&opt draw]
    (default draw true)
    (def new-pos (rawterm/buffer-traverse buf pos -1 true))
    (when new-pos
      (set pos new-pos)
      (if draw (refresh))))

  (defn- kleftw
    []
    (while (and (> pos 0) (= 32 (buf (dec pos)))) (kleft false))
    (while (and (> pos 0) (not= 32 (buf (dec pos)))) (kleft false))
    (refresh))

  (defn- kright
    [&opt draw]
    (default draw true)
    (def new-pos (or (rawterm/buffer-traverse buf pos 1 true) (length buf)))
    (set pos new-pos)
    (if draw (refresh)))

  (defn- krightw
    []
    (while (and (< pos (length buf)) (not= 32 (buf pos))) (kright false))
    (while (and (< pos (length buf)) (= 32 (buf pos))) (kright false))
    (refresh))

  (defn- khome
    []
    (set pos 0)
    (refresh))

  (defn- kend
    []
    (set pos (length buf))
    (refresh))

  (defn- kback
    [&opt draw]
    (default draw true)
    (def new-pos (rawterm/buffer-traverse buf pos -1 true))
    (when new-pos
      (buffer/blit buf buf new-pos pos)
      (buffer/popn buf (- pos new-pos))
      (set pos new-pos)
      (if draw (refresh))))

  (defn- kbackw
    []
    (while (and (> pos 0) (= 32 (buf (dec pos)))) (kback false))
    (while (and (> pos 0) (not= 32 (buf (dec pos)))) (kback false))
    (refresh))

  (defn- kdelete
    [&opt draw]
    (default draw true)
    (kright false)
    (kback draw))

  (defn- kdeletew
    []
    (while (and (< pos (length buf)) (= 32 (buf pos))) (kdelete false))
    (while (and (< pos (length buf)) (not= 32 (buf pos))) (kdelete false))
    (refresh))

  (fn getline-fn
    [&named prompt raw-prompt buff _]
    (eprin "\r")
    (eflush)
    (set buf (or buff @""))
    (set prpt (string prompt))
    (set prpt-width (rawterm/monowidth raw-prompt))
    (unless (rawterm/isatty)
      (break (getline prpt buf)))
    (buffer/clear tmp-buf)
    (buffer/clear buf)
    (set ret-value buf)
    (set pos 0)
    (set lines-below 0)
    (set more-input true)
    (eprin prpt)
    (eflush)
    # (array/push history "")
    # (if (> (length history) max-history) (array/remove history 0))
    # (var hindex (dec (length history)))
    (while more-input
      (def c (getc))
      (def [_h _w] (rawterm/size))
      (set w _w)
      (set h _h)
      (if (>= c 0x20)
        (case c
          127 (kback)
          (when (>= c 0x20)
            (insert input-buf true)))
        (case c
          1 # ctrl-a
          (khome)
          2 # ctrl-b
          (kleft)
          3 # ctrl-c
          # (do (clear-lines) (eprint "^C") (eflush) (rawterm/end) (os/exit 1))
          (do (clear-lines)
              (error {:message "Keyboard interrupt"}))
          4 # ctrl-d, eof
          (if (= pos (length buf) 0)
            (do (set more-input false) (clear-lines))
            (kdelete))
          5 # ctrl-e
          (kend)
          6 # ctrl-f
          (kright)
          7 # ctrl-g
          nil # (showdoc)
          8 # ctrl-h
          (kbackw)
          9 # tab
          (autocomplete)
          12 # ctrl-l
          nil # (do (clear) (refresh))
          13 # enter
          (do (set more-input false) (clear-lines))
          14 # ctrl-n
          nil # (set hindex (history-move hindex -1))
          16 # ctrl-p
          nil # (set hindex (history-move hindex 1))
          17 # ctrl-q
          nil # (do (set more-input false) (set ret-value :cancel) (clear-lines))
          23 # ctrl-w
          (kbackw)
          26 # ctrl-z
          nil # (do (rawterm/ctrl-z) (refresh))
          27 # escape sequence, process more
          (case (getc)
            (chr "[")
            (let [c3 (getc)]
              (cond
                (and (>= c3 (chr "0")) (<= c3 (chr "9")))
                (case (def c4 (getc))
                  (chr "1") (khome)
                  (chr "3") (kdelete)
                  (chr "4") (kend)
                  126 (kdelete))
                (= c3 (chr "O"))
                (case (getc)
                  (chr "H") (khome)
                  (chr "F") (kend))
                (= c3 (chr "A")) nil # (set hindex (history-move hindex -1))
                (= c3 (chr "B")) nil # (set hindex (history-move hindex 1))
                (= c3 (chr "C")) (kright)
                (= c3 (chr "D")) (kleft)
                (= c3 (chr "H")) (khome)
                (= c3 (chr "F")) (kend)))
            (chr "d") (kdeletew) # alt-d
            (chr "b") (kleftw) # alt-b
            (chr "f") (krightw) # alt-f
            (chr ",") nil # (set hindex (history-move hindex (- max-history)))
            (chr ".") nil # (set hindex (history-move hindex max-history))
            127 (kbackw)
            nil))))
    (eprint)
    ret-value))