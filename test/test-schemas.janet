(use judge)
(use ../src/schemas)

(deftest "choices-schema, should pass"
  (test (choices-schema ["abc" "123"]) ["abc" "123"]))

(deftest "choices-schema, should fail"
  (test-error (choices-schema ["abc" 123]) "failed clause (or :string :buffer), choice failed"))

(deftest "question-schema, should pass"
  (def sample-question
    {:label "question" :question "What would you like?" :type :text})
  (test (question-schema sample-question)
        {:label "question"
         :question "What would you like?"
         :type :text}))

(deftest "question-schema, should pass with unnecessary key included"
  (def sample-question
    {:label "question" :question "What would you like?" :type :text :unnecessary-key true})
  (test (question-schema sample-question)
    {:label "question"
     :question "What would you like?"
     :type :text
     :unnecessary-key true}))

(deftest "question-schema, should error"
  (def sample-question
    {:label "question" :question "What would you like?" :type 123})
  (test-error (question-schema sample-question) "failed clause (enum :text :select :checkbox :password \"text\" \"select\" \"checkbox\" \"password\"), expected one of (:text :select :checkbox :password \"text\" \"select\" \"checkbox\" \"password\"), got 123"))

(deftest "question-schema, should error"
  (def sample-question
    {:label "question" :question "What would you like?"})
  (test-error (question-schema sample-question) "failed clause (enum :text :select :checkbox :password \"text\" \"select\" \"checkbox\" \"password\"), expected one of (:text :select :checkbox :password \"text\" \"select\" \"checkbox\" \"password\"), got nil"))

(deftest "question-schema, with checkbox choices"
  (def sample-question
    {:label "question" :question "What would you like?" :type :checkbox :choices ["Option a" "Option b"]})
  (test (question-schema sample-question)
        {:choices ["Option a" "Option b"]
         :label "question"
         :question "What would you like?"
         :type :checkbox}))

(deftest "question-schema, checkbox missing choices"
  (def sample-question
    {:label "question" :question "What would you like?" :type :checkbox})
  (test-error (try (question-schema sample-question) ([_] (error "Errored"))) "Errored"))

(deftest "question-schema, incorrect checkbox choices"
  (def sample-question
    {:label "question" :question "What would you like?" :type :checkbox :choices ["Option a" 123]})
  (test-error (try (question-schema sample-question) ([_] (error "Errored"))) "Errored"))

(deftest "question-list-schema"
  (def sample-question-1
    {:label "q1" :question "What is your favorite color?" :type :text})
  (def sample-question-2
    {:label "q2" :question "Pizza or icecream?" :type :select :choices ["Pizza" "Icecream"]})
  (def sample-question-3
    {:label "q3" :question "Check all that apply" :type :checkbox :choices ["Overworked" "Underpaid"]})
  (test (question-list-schema [sample-question-1
                               sample-question-2
                               sample-question-3])
        [{:label "q1"
          :question "What is your favorite color?"
          :type :text}
         {:choices ["Pizza" "Icecream"]
          :label "q2"
          :question "Pizza or icecream?"
          :type :select}
         {:choices ["Overworked" "Underpaid"]
          :label "q3"
          :question "Check all that apply"
          :type :checkbox}]))

(deftest "question-list-schema, should error"
  (def sample-question-1
    {:label "q1" :question "What is your favorite color?" :type :text})
  (def sample-question-2
    {:label "q2" :question "Pizza or icecream?" :type :select :choices ["Pizza" "Icecream" 123]})
  (def sample-question-3
    {:label "q3" :question "Check all that apply" :type :checkbox :choices ["Overworked" "Underpaid"]})
  (test-error (question-list-schema [sample-question-1
                                     sample-question-2
                                     sample-question-3]) "failed clause (or :string :buffer), choice failed"))

(deftest "question-or-list-schema, should pass"
  (def sample-question
    {:label "question" :question "What would you like?" :type :text})
  (test (question-or-list-schema sample-question)
    {:label "question"
     :question "What would you like?"
     :type :text}))

(deftest "question-or-list-schema, should pass" 
  (def sample-question-list
    [{:label "q1"
      :question "What is your favorite color?"
      :type :text}
     {:choices ["Pizza" "Icecream"]
      :label "q2"
      :question "Pizza or icecream?"
      :type :select}
     {:choices ["Overworked" "Underpaid"]
      :label "q3"
      :question "Check all that apply"
      :type :checkbox}])
  (test (question-or-list-schema sample-question-list)
    [{:label "q1"
      :question "What is your favorite color?"
      :type :text}
     {:choices ["Pizza" "Icecream"]
      :label "q2"
      :question "Pizza or icecream?"
      :type :select}
     {:choices ["Overworked" "Underpaid"]
      :label "q3"
      :question "Check all that apply"
      :type :checkbox}]))

(deftest "question-or-list-schema, should fail"
  (def sample-question
    {:label "question" :question 123 :type :text})
  (test-error (question-or-list-schema sample-question)
    "failed clause (or (pred (short-fn (try (question-schema $) ([_] false)))) (pred (short-fn (try (question-list-schema $) ([_] false))))), choice failed"))

(deftest "question-or-list-schema, should pass" 
  (def sample-question-list
    [{:label "q1"
      :question "What is your favorite color?"
      :type :text}
     {:label "q2"
      :question "Pizza or icecream?"
      :type :select
      :choices ["Pizza" "Icecream"]}
     {:label "q3"
      :question "Check all that apply"
      :type :checkbox
      :choices ["Overworked" 123]}])
  (test-error (question-or-list-schema sample-question-list)
    "failed clause (or (pred (short-fn (try (question-schema $) ([_] false)))) (pred (short-fn (try (question-list-schema $) ([_] false))))), choice failed"))