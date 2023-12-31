(use judge) 
(import /src/init :as journo)

(def test-interview
  [{:label "q1"
    :question "Choose a file"
    :type :path}])

(defn main [& args]
  (eprint "[TEST] Please answer the following question.")
  (eprint "")
  (eprint "------------------------")
  (eprint "")
  (def answers (journo/interview test-interview :keywordize true))
  (comment pp answers)
  (eprint "")
  (eprint "------------------------")
  (eprint "")
  (eprint "Got this answer:\n")
  (eprint ((answers :q1) :question))
  (eprint "  " ((answers :q1) :answer)) 
  (eprint ""))
