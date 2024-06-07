(import spork/schema)

(use judge)

# (def dict-schema
#   (schema/predicate
#    (and (or :struct :table)
#         (keys (or :string :buffer))
#         (values (or :string :buffer)))))

(def indexed-schema
  (schema/predicate
    (and (or :array :tuple)
         (values (or :string :buffer
                     :table :struct)))))

(def choices-schema
  (schema/validator
    (pred |(indexed-schema $))))

(test (choices-schema ["abc" "123"]) ["abc" "123"])
(test (choices-schema [{"abc" true} {"123" true}]) [{"abc" true} {"123" true}])
(test-error (try (choices-schema [:abc "123"]) ([_] (error "Errored"))) "Errored")
(test-error (try (choices-schema {:abc "123"}) ([_] (error "Errored"))) "Errored")
(test-error (try (choices-schema ["abc" 123]) ([_] (error "Errored"))) "Errored")
(test-error (try (choices-schema {"abc" 123}) ([_] (error "Errored"))) "Errored")

(def question-schema
  (schema/validator
    (and (props :label (or :string :keyword)
                :question (or :string :buffer)
                :type (enum :text :select :checkbox :password :path
                            "text" "select" "checkbox" "password" "path"))
         (pred |(if (has-value? [:checkbox :select "checkbox" "select"] ($ :type))
                  (and ($ :choices) (choices-schema ($ :choices)))
                  true))))) # TODO: Add :path :raw-select :autocomplete :any-key :option-abbrevs

(def question-list-schema
  (schema/validator
    (and (or :array :tuple)
         (values (pred question-schema)))))

(def question-or-list-schema
  (schema/validator
    (or (pred |(try (question-schema $) ([_] false)))
        (pred |(try (question-list-schema $) ([_] false))))))
