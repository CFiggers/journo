(import spork/schema)

(use judge)

(def dict-schema
  (schema/predicate
   (and (or :struct :table)
        (keys (or :string :buffer))
        (values (or :string :buffer)))))

(def indexed-schema
  (schema/predicate
   (and (or :array :tuple)
        (values (or :string :buffer)))))

(def choices-schema
  (schema/validator
   (pred |(or (dict-schema $) (indexed-schema $)))))

(test (choices-schema ["abc" "123"]) ["abc" "123"])
(test (choices-schema {"abc" "123"}) {"abc" "123"})
(test-error (choices-schema [:abc "123"]) "failed clause (pred (short-fn (or (dict-schema $) (indexed-schema $)))), predicate <tuple 0x562110FDC650> failed for value <tuple 0x562111163AA0>")
(test-error (choices-schema {:abc "123"}) "failed clause (pred (short-fn (or (dict-schema $) (indexed-schema $)))), predicate <tuple 0x562110FDC650> failed for value <struct 0x5621110F24F8>")
(test-error (choices-schema ["abc" 123]) "failed clause (pred (short-fn (or (dict-schema $) (indexed-schema $)))), predicate <tuple 0x562110FDC650> failed for value <tuple 0x562110EFA5D0>")
(test-error (choices-schema {"abc" 123}) "failed clause (pred (short-fn (or (dict-schema $) (indexed-schema $)))), predicate <tuple 0x562110FDC650> failed for value <struct 0x562110F2EAD8>")

(def question-schema
  (schema/validator
   (and (props :label (or :string :keyword)
               :question (or :string :buffer)
               :type (enum :text :select :checkbox :password
                           "text" "select" "checkbox" "password"))
        (pred |(if (has-value? [:checkbox :select "checkbox" "select"] ($ :type))
                 (and ($ :choices) (choices-schema ($ :choices)))
                 true))))) # TODO: Add :password :filepath :raw-select :autocomplete :any-key

(def question-list-schema
  (schema/validator
   (and (or :array :tuple)
        (values (pred question-schema)))))

(def question-or-list-schema
  (schema/validator
   (or (pred |(try (question-schema $) ([_] false)))
       (pred |(try (question-list-schema $) ([_] false))))))


