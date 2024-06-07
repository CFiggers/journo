(use judge)
(import /src/init :as journo)

(def test-interview
  [{:label "q1"
    :question "What is your favorite color?"
    :type :text}
   {:label "q2"
    :question "Please set a password"
    :type :password}
   {:label "q3"
    :question "Pizza or icecream?"
    :type :select
    :choices [{"Pizza" "p"} {"Icecream" "i"}]}
   {:label "q4"
    :question "Check all that apply"
    :type :checkbox
    :choices [{"Overworked" "o"} {"Underpaid" "u"} {"Insides Out" "i"} {"Outsides In" "n"}]}
   {:label "q5"
    :question "Pick a file"
    :type :path}])

(defn main [& args]
  (eprint "[TEST] Please answer the following questions.")
  (eprint "")
  (eprint "------------------------")
  (eprint "")
  (def answers (journo/interview test-interview :keywordize true))
  (comment pp answers)
  (eprint "")
  (eprint "------------------------")
  (eprint "")
  (eprint "Got these answers:\n")
  (eprint ((answers :q1) :question))
  (eprint "  " ((answers :q1) :answer))
  (eprint ((answers :q2) :question))
  (eprint "  " ((answers :q2) :answer))
  (eprint ((answers :q3) :question))
  (eprint "  " ((answers :q3) :answer))
  (eprint ((answers :q4) :question))
  (eprint (string/format "  %q" ((answers :q4) :answer)))
  (eprint ((answers :q5) :question))
  (eprint "  " ((answers :q5) :answer))
  (eprint ""))
