(import spork/rawterm)
(import spork/path)
(use judge)

(import ./getline)
(use ./schemas)
(use ./color)
(use ./utils)

(import ./termcodes :as terminal)

(defn set-size
  [rows cols]
  (setdyn :size/rows rows)
  (setdyn :size/cols cols))

(defmacro handle-resize []
  '(let [[new-rows new-cols] (rawterm/size)]
     (when (not= (dyn :size/rows) new-rows)
       (setdyn :size/rows new-rows))
     (when (not= (dyn :size/cols) new-cols)
       (setdyn :size/cols new-cols))))

(defn gather-multi-byte-input []
  (let [[c] (rawterm/getch)]
    (when (= c (chr "["))
      (let [[d] (rawterm/getch)]
        (case d
          (chr "A") :arrow-up
          (chr "B") :arrow-down
          (chr "C") :arrow-right
          (chr "D") :arrow-left)))))

(defn get-cursor-pos []
  (var ret @"")
  (terminal/query-cursor-position)
  (forever
    (rawterm/getch ret)
    (when (= (last ret) (chr "R")) (break)))
  (peg/match '(* "\e[" (number :d+) ";" (number :d+) "R") ret))

(defn cursor-go-to-pos [[row col]]
  (prin (string/format "\e[%d;%dH" row col)))

(defn show-error
  ``
  Display an error at the bottom of the terminal.
  ``
  [err-text]
  (def current-loc (get-cursor-pos))
  (cursor-go-to-pos [(dyn :size/rows) 2])
  (cprin err-text {:color :red})
  (cursor-go-to-pos current-loc))

(defn clear-error
  ``
  Clear any errors showing at the bottom of the terminal.
  ``
  []
  (def current-loc (get-cursor-pos))
  (cursor-go-to-pos [(dyn :size/rows) 2])
  (terminal/clear-line)
  (cursor-go-to-pos current-loc))

(defn render-options
  [&keys {:starting-pos starting-pos
          :choices choices
          :current-choice current-choice
          :current-selections current-selections
          :init init
          :multi multi
          :offset offset}]
  (when init
    (print ""))
  (cursor-go-to-pos [(+ (starting-pos 0) offset 1) 0])
  (for i 0 (length choices)
    (if (= current-choice i)
      (prin "  » ")
      (prin "    "))
    (when multi
      (if (has-value? current-selections i)
        (prin "● ")
        (prin "○ ")))
    (prin (choices i))
    (when (< i (dec (length choices))) (print ""))))

(defmacro unwind-choices [n]
  ~(repeat ,n (do (terminal/clear-line)
                  (terminal/cursor-up))))

(defn collect-choices [question &named multi]
  (var in-choices (question :choices))
  (var cursor-pos (get-cursor-pos))
  (var current-choice 0)
  (var current-selections @[])
  (var tip (if multi "(Use arrow keys to move, <space> to select, <a> toggles all, <i> inverts current selection)"
             "(Use arrow keys to move, <enter> to confirm)"))
  (var offset 0)
  (comment os/sleep 6)
  (let [tip-len (rawterm/monowidth tip)
        line-len (+ tip-len (cursor-pos 0))]
    (if (> line-len (dyn :size/cols))
      (do (cprint (string/slice tip 0 (- (dyn :size/cols) (cursor-pos 1))) {:color :grey})
          (var cursor (- (dyn :size/cols) (cursor-pos 1)))
          (while (>= (- tip-len cursor) (dyn :size/cols))
            (cprint (string/slice tip cursor (+ cursor (dyn :size/cols))) {:color :grey})
            (+= cursor (dyn :size/cols))
            (+= offset 1))
          (cprin (string/slice tip cursor) {:color :grey})
          (+= offset 1))
      (cprin tip {:color :grey})))
  (def choices
    (seq [choice :in in-choices]
      (cond
        (bytes? choice) choice
        (dictionary? choice) (first (keys choice)))))
  (render-options
    :starting-pos cursor-pos
    :choices choices
    :current-choice current-choice
    :current-selections current-selections
    :multi multi
    :init true
    :offset offset)
  (update cursor-pos 0 |(- $ (+ (max 0 (- (+ $ (length choices) offset) (dyn :size/rows))))))
  (forever
    (handle-resize)
    (let [[c] (rawterm/getch)
          max-choice (dec (length choices))
          cursor-up |(do (set current-choice (dec current-choice))
                         (when (= current-choice -1) (set current-choice (dec (length choices)))))
          cursor-down |(do (set current-choice (inc current-choice))
                           (when (> current-choice (dec (length choices))) (set current-choice 0)))]
      (case c
        2 (set current-choice 0)
        3 (do (unwind-choices (+ (length choices) offset))
              (cursor-go-to-pos cursor-pos)
              (error {:message "Keyboard interrupt"
                      :cursor [(first cursor-pos) 0]}))
        4 (cursor-down)
        6 (set current-choice (dec (length choices)))
        13 (do (break))
        14 (cursor-down)
        21 (cursor-up)
        27 (case (gather-multi-byte-input)
             :arrow-up (cursor-up)
             :arrow-down (cursor-down))
        32 (when multi
             (if-let [n (index-of current-choice current-selections)]
               (array/remove current-selections n)
               (array/push current-selections current-choice)))
        106 (cursor-down)
        107 (cursor-up)
        1011 (set current-choice 0)
        1012 (cursor-up)
        (chr "a") (if (= (length current-selections)
                         (length choices))
                    (set current-selections @[])
                    (set current-selections (range (length choices))))
        (chr "i") (set current-selections
                       (filter |(not= "" $)
                               (seq [i :range [0 (length choices)]]
                                 (if (has-value? current-selections i) "" i))))))
    (render-options
      :starting-pos cursor-pos
      :choices choices
      :current-choice current-choice
      :current-selections current-selections
      :multi multi
      :offset offset))
  (unwind-choices (+ (length choices) offset))
  (cursor-go-to-pos cursor-pos)
  (let [results (if multi
                  (map |(choices $) current-selections)
                  [(choices current-choice)])
        mask-results (seq [result :in results]
                       (var ret "")
                       (if (has-value? in-choices result)
                         (set ret result)
                         (each in-choice in-choices
                           (pp result)
                           (pp in-choice)
                           (when (and (dictionary? in-choice)
                                      (= (first (keys in-choice)) result))
                             (set ret (first (values in-choice))))))
                       ret)
        results-string (if multi (string/join mask-results ", ")
                         (first mask-results))]
    (terminal/clear-line-forward)
    (cprint results-string {:color :turquoise})
    (comment print "  [collect-choice] current-choice: " current-choice)
    (if multi mask-results (first mask-results))))

(comment (def prefix "."))

(defn filepath-autocomplete [prefix &]
  (def rel-parts (path/parts prefix))
  (def abs-parts (path/parts (path/abspath prefix)))
  (def rel (if (= "." (first rel-parts)) "./" ""))
  (def files (if (= "." prefix)
               (filter |(not= "" $) (os/dir (path/abspath prefix)))
               (->> (os/dir (apply path/join (drop -1 abs-parts)))
                    (filter |(string/has-prefix? (last abs-parts) $)))))
  (def ret (seq [file :in files]
             (string rel
                     (path/join
                       ;(drop -1 rel-parts)
                       (if (= :directory (os/stat file :mode))
                         (string file path/sep) file)))))
  (if (and (= 1 (length ret)) (deep= (first ret) prefix) (= :directory (os/stat (first ret) :mode)))
    (filepath-autocomplete (string prefix path/sep)) ret))

(test (filepath-autocomplete ".")
      @["./example/"
        "./src/"
        "./.gitignore"
        "./LICENSE"
        "./project.janet"
        "./README.md"
        "./.lsp/"
        "./.clj-kondo/"
        "./.git/"
        "./scratch.janet"
        "./media/"
        "./test/"])
(test (filepath-autocomplete "./")
      @["./example/"
        "./src/"
        "./.gitignore"
        "./LICENSE"
        "./project.janet"
        "./README.md"
        "./.lsp/"
        "./.clj-kondo/"
        "./.git/"
        "./scratch.janet"
        "./media/"
        "./test/"])
(test (filepath-autocomplete "e") @["example/"])
(test (filepath-autocomplete "src") @["src/"])
(test (filepath-autocomplete "src/")
      @["src/init.janet"
        "src/getline.janet"
        "src/journo.janet"
        "src/color.janet"
        "src/utils.janet"
        "src/termcodes.janet"
        "src/schemas.janet"])
(test (filepath-autocomplete "./src/")
      @["./src/init.janet"
        "./src/getline.janet"
        "./src/journo.janet"
        "./src/color.janet"
        "./src/utils.janet"
        "./src/termcodes.janet"
        "./src/schemas.janet"])
(test (filepath-autocomplete "./test/j") @["./test/junk"])
(test (filepath-autocomplete "./test/junk")
      @["./test/junk/__pycache__"
        "./test/junk/test-journo.hy"
        "./test/junk/test.hy"
        "./test/junk/capture.hy"
        "./test/junk/output"
        "./test/junk/capture.py"
        "./test/junk/janet"
        "./test/junk/goodcapture.py"])

(defn collect-text-input [question &named redact file]
  (terminal/enable-cursor)
  (var response @"")
  (def gl (getline/make-getline nil (if file filepath-autocomplete nil) nil redact))
  (forever
    (set response (gl :prompt (string (cformat " ? " {:color :grey}) (cformat (string (question :question) " ") {:effects [:bold]}))
                      :raw-prompt (string " ? " (question :question) " ")))
    (comment print "  [collect-text-input] response: " response)
    (terminal/hide-cursor)
    (if file
      (if (os/stat (string response))
        (do (clear-error) (break))
        (show-error "File not found. Please try again"))
      (break)))
  response)

(defn collect-answer [question]
  (case (keyword (question :type))
    :text (collect-text-input question)
    :password (collect-text-input question :redact true)
    :path (collect-text-input question :file true)
    :select (collect-choices question)
    :checkbox (collect-choices question :multi true)
    (error "bad question type (this error should be unreachable)")))

# TODO: Handle terminal resizing
# TODO: Handle cancellation/keyboard interrupt
# TODO: Handle when instructions loop off the side of the screen

(defmacro cleanup-rawterm []
  ~(do
     (rawterm/end)
     (terminal/enable-cursor)))

(defn interview*
  ``
  This is the function form of the `journo/ask` and `journo/interview` 
  macros.

  The main entry function for initiating a question and answer session
  in a CLI. Pass a question or indexed datastructure of questions to
  this function to have each one asked in order at the command line. 

  Returns a table of user inputs captured for each question.
  ``
  [qs &named keywordize]
  (question-list-schema qs)
  (var answers
    (tabseq [q :in qs]
      (if keywordize (keyword (q :label)) (q :label))
      (put (from-pairs (pairs q)) :label nil)))
  (try
    (defer (cleanup-rawterm)
      (rawterm/begin set-size)
      (terminal/hide-cursor)
      (set-size ;(rawterm/size))
      (var question-home "")
      (each question qs
        (let [key (if keywordize (keyword (question :label)) (question :label))]
          (set question-home (get-cursor-pos))
          (prin (cformat " ? " {:color :grey}) (cformat (string (question :question) " ") {:effects [:bold]}))
          (try
            (put-in answers [key :answer] (collect-answer question))
            ([err fib]
              (if (and (dictionary? err)
                       (= (err :message) "Keyboard interrupt"))
                (do
                  (cursor-go-to-pos (or (err :cursor) question-home))
                  (when (err :offset) (terminal/cursor-up (err :offset)))
                  (cprin (string " ? " (question :question) " ") {:color :grey})
                  (terminal/cursor-down)
                  (print "\n\nCancelled by user")
                  (error :exit))
                (propagate err fib)))))))
    ([err fib]
      (if (= err :exit)
        (os/exit 1)
        (propagate err fib))))
  (comment pp answers)
  answers)

# TODO: Response validation
# TODO: Passing in Styles
# TODO: Testing

(defmacro interview
  ``
  Pass an indexed datastructure of questions to this function to have 
  each one asked in order at the command line. 

  Questions must be a dictionary (table or struct) and contain `:label`, 
  `:question`, and `type`. `type` can be one of:
  
   - `:text` or "text" = Open input
   - `:password` or "password" = Open input, replaced with `*` in terminal
   - `:select` or "select" = Single choice (provide with `:choices`)
   - `:checkbox` = Multiple choice (provide with `:choices`)
   - `:path` = The path of a file in the current directory (suggest options with `Tab`)
  
  Example: 

    `(journo/interview 
      [{:label :q1 :question "Who?" :type :text} 
       {:label :q2 :question "What?" :type :select 
                   :choices ["Me" "Not me"]}])`
       
  Returns a table of user inputs as captured for each question.
  ``
  [questions &named keywordize]
  ~(,interview* ,questions :keywordize ,keywordize))

(defmacro ask
  ``
  Pass a single question to this function to have it asked at the command 
  line. 
  
  The question must be a dictionary (table or struct) and contain `:label`, 
  `:question`, and `type`. `type` can be one of:
  
   - `:text` or "text" = Open input
   - `:password` or "password" = Open input, replaced with `*` in terminal
   - `:select` or "select" = Single choice (provide with `:choices`)
   - `:checkbox` = Multiple choice (provide with `:choices`)
   - `:path` = The path of a file in the current directory (suggest options with `Tab`)
  
  Example: 
  
    `(journo/ask {:label :q1 :question "Who?" :type :text})`
       
  Returns a single table containing `:question` and ':answer'.
  ``
  [question &named keywordize]
  (let [question (when (nil? (question :label)) (put (from-pairs (pairs question)) :label (string (gensym))))]
    ~((,interview* [,question] :keywordize ,keywordize) (,question :label))))
