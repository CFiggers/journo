(use judge)
(use ./utils)

(defn color-string [text color-key]
  (if-let [color-code
           (case color-key
             :black "0;30" :red "0;31"
             :green "0;32" :yellow "0;33"
             :blue "0;34" :magenta "38;2;197;134;192"
             :cyan "0;36" :white "0;37"
             :brown "38;2;206;145;120"
             :grey "38;2;118;118;118"
             :cream-green "38;2;181;206;168"
             :powder-blue "38;2;156;220;254"
             :drab-green "38;2;106;153;85"
             :goldenrod "38;2;85;65;13"
             :turquoise "38;2;97;214;214"
             :default "0;39")]
    (string "\e[" color-code "m" text "\e[0;39m")
    text))

(defn bg-color-string [text color-key]
  (if-let [color-code
           (case color-key
             :black "0;40" :red "0;41"
             :green "0;42" :yellow "0;43"
             :blue "0;44" :magenta "0;45"
             :cyan "0;46" :white "0;47"
             :default "0;49"
             :dull-blue "48;2;38;79;120")]
    (string "\e[" color-code "m" text "\e[0;49m")
    text))

(defn effects-string [text effects]
  (if-let [codes (seq [effect :in effects]
                   (case effect
                     :bold "1"
                     :underline "4"
                     :italic "3"
                     :crossed-out "9"
                     ""))
           filtered-codes (filter |(not= "" $) codes)]
    (string "\e[" (string/join filtered-codes ";") "m" text "\e[0m")
    text))

(defn cprint* [text color background effects newline]
  (default effects [])
  (-> text
      (color-string color)
      (bg-color-string background)
      (effects-string effects)
      (|(if newline (string $ "\n") $))))

(deftest "cprint*"
  (test (cprint* "Hello there" :grey nil nil nil) "\e[m\e[38;2;118;118;118mHello there\e[0;39m\e[0m")
  (test (cprint* "Hello there" :grey nil nil true) "\e[m\e[38;2;118;118;118mHello there\e[0;39m\e[0m\n")
  (test (cprint* "Hello there" :grey nil [:bold] true) "\e[1m\e[38;2;118;118;118mHello there\e[0;39m\e[0m\n"))

(defmacro cprin [text {:color color :background background :effects effects}]
  ~(prin (cprint* ,text ,color ,background ,effects false)))

(defmacro cprint [text {:color color :background background :effects effects}]
  ~(prin (cprint* ,text ,color ,background ,effects true)))

(test-macro (cprin "Hello there" {:color :grey})
  (prin (cprint* "Hello there" :grey nil nil false)))