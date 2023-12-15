(import spork/rawterm)
(import spork/getline)
(use judge)

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

(defn render-options
  [&keys {:starting-pos starting-pos
          :choices choices
          :current-choice current-choice
          :current-selections current-selections
          :init init
          :multi multi}]
  (when init
    (print ""))
  (cursor-go-to-pos [(inc (starting-pos 0)) 0])
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

(defn collect-choices [choices &named multi]
  (var cursor-pos (get-cursor-pos))
  (var current-choice 0)
  (var current-selections @[])
  (cprin (if multi "(Use arrow keys to move, <space> to select, <a> toggles all, <i> inverts current selection)"
                   "(Use arrow keys to move, <enter> to confirm)")
         {:color :grey})
  (render-options
   :starting-pos cursor-pos
   :choices choices
   :current-choice current-choice
   :current-selections current-selections
   :multi multi
   :init true)
  (update cursor-pos 0 |(- $ (+ (max 0 (- (+ $ (length choices)) (dyn :size/rows))))))
  (forever
   (handle-resize)
   (let [[c] (rawterm/getch)
         max-choice (dec (length choices))]
     (case c
       3 (do (unwind-choices (length choices))
             (cursor-go-to-pos cursor-pos)
             (error {:message "Keyboard interrupt"
                     :cursor [(first cursor-pos) 0]}))
       27 (case (gather-multi-byte-input)
            :arrow-up (set current-choice (max (dec current-choice) 0))
            :arrow-down (set current-choice (min (inc current-choice) max-choice)))
       32 (when multi
           (if-let [n (index-of current-choice current-selections)]
             (array/remove current-selections n)
             (array/push current-selections current-choice)))
       13 (do (break))
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
    :multi multi))
  (unwind-choices (length choices))
  (cursor-go-to-pos cursor-pos)
  (let [results (if multi
                  (map |(choices $) current-selections)
                  (choices current-choice))
        results-string (if multi (string/join results ", ")
                           results)]
    (terminal/clear-line-forward)
    (cprint results-string {:color :turquoise})
    (comment print "  [collect-choice] current-choice: " current-choice)
    results))

(defn collect-text-input [&named redact]
  (terminal/enable-cursor)
  (var response @"")
  (forever
   (handle-resize)
   (let [[c] (rawterm/getch)]
     (case c
       3 (error {:message "Keyboard interrupt"})
       13 (do (print "") (break))
       127 (do (buffer/popn response 1) (prin "\b") (prin " ") (prin "\b"))
       (do (cprin (if redact "*" (string/from-bytes c)) {:color :turquoise})
           (buffer/push response (string/from-bytes c))))))
  (comment print "  [collect-text-input] response: " response)
  (terminal/hide-cursor)
  response)

(defn collect-answer [question]
  (case (question :type)
    :text     (collect-text-input)
    "text"    (collect-text-input)
    :password (collect-text-input :redact true)
    "password" (collect-text-input :redact true)
    :select   (collect-choices (question :choices))
    "select"   (collect-choices (question :choices))
    :checkbox (collect-choices (question :choices) :multi true)
    "checkbox" (collect-choices (question :choices) :multi true)))

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
          (cprin " ? " {:color :grey})
          (cprin (string (question :question) " ") {:effects [:bold]})
          (try
            (put-in answers [key :answer] (collect-answer question))
            ([err fib]
             (if (and (dictionary? err) 
                      (= (err :message) "Keyboard interrupt"))
               (do
                 (cursor-go-to-pos (or (err :cursor) question-home))
                 (prin)
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
  
  Example: 
  
    `(journo/ask {:label :q1 :question "Who?" :type :text})`
       
  Returns a single table containing `:question` and ':answer'.
  ``
  [question &named keywordize]
  (let [question (when (nil? (question :label)) (put (from-pairs (pairs question)) :label (string (gensym))))]
    ~((,interview* [,question] :keywordize ,keywordize) (,question :label))))
