(import spork/rawterm)
(import spork/getline)
(use judge)

(use ./schemas)
(use ./color)
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
         (prin "  »")
         (prin "   "))
       (when multi
         (if (has-value? current-selections i)
           (prin " ● ")
           (prin " ○ ")))
       (prin (choices i))
       (when (< i (dec (length choices))) (print ""))))

(defmacro unwind-choices [n]
  ~(repeat ,n (do (terminal/clear-line)
                  (terminal/cursor-up))))

(defn collect-choices [choices &named multi]
  (var cursor-pos (get-cursor-pos))
  (var current-choice 0)
  (var current-selections @[])
  (cprin (if multi "(User arrow keys to move, <space> to select, <a> toggles all, <i> inverts current selection)"
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
       13 (do (break))))
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

(defn collect-text-input []
  (terminal/enable-cursor)
  (var response @"")
  (forever
   (handle-resize)
   (let [[c] (rawterm/getch)]
     (case c
       3 (error {:message "Keyboard interrupt"})
       13 (do (print "") (break))
       127 (do (buffer/popn response 1) (prin "\b") (prin " ") (prin "\b"))
       (do (cprin (string/from-bytes c) {:color :turquoise})
           (buffer/push response (string/from-bytes c))))))
  (comment print "  [collect-text-input] response: " response)
  (terminal/hide-cursor)
  response)

(defn collect-answer [question]
  (case (question :type)
    :text     (collect-text-input)
    :select   (collect-choices (question :choices))
    :checkbox (collect-choices (question :choices) :multi true)))

# TODO: Handle terminal resizing
# TODO: Handle cancellation/keyboard interrupt

(defmacro cleanup-rawterm []
  ~(do
     (rawterm/end)
     (terminal/enable-cursor)))

(defn interview*
  ``
  The main entry function for initiating a question and answer session
  in a CLI. Pass a question or indexed datastructure of questions to
  this function to have each one asked in order at the command line.

  Returns a table of user inputs captured for each question.
  ``
  [&opt qs &named keywordize]
  (question-list-schema qs)
  (var answers @{})
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
           (put answers key {:question (question :question)
                             :answer (collect-answer question)})
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

(defmacro interview
  ``
  The main entry function for initiating a question and answer session
  in a CLI. Pass a question or indexed datastructure of questions to
  this function to have each one asked in order at the command line.

  Returns a table of user inputs captured for each question.
  ``
  [qs &named keywordize]
  ~(,interview* ,qs :keywordize ,keywordize))

(defmacro ask
  [&opt q &named keywordize]
  (let [q (when (nil? (q :label)) (put q :label (gensym)))]
    ~((,interview* [,q] :keywordize ,keywordize) (,q :label))))
