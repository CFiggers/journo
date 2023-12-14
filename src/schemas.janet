(import spork/schema)

(use judge)

(def choices-schema
  (schema/validator
   (and (or :array :tuple)
        (values :string))))

(def question-schema
  (schema/validator
   (and (props :label :string
               :question :string
               :type (enum :text :select :checkbox :password))
        (pred |(if (has-value? [:checkbox :select] ($ :type))
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


