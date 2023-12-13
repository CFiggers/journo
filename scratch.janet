(import spork/rawterm)

(defn get-cursor-pos []
  (var ret @"")
  (prin "\e[6n")
  (forever
   (rawterm/getch ret)
   (when (= (last ret) (chr "R")) (break))) 
  (peg/match '(* "\e[" (number :d+) ";" (number :d+) "R") ret))

(defer (rawterm/end)
       (rawterm/begin)
       (for i 0 20
        (let [[c] (rawterm/getch)]
          (case c 
            (chr "s") (pp (get-cursor-pos))
            (print "Got a " (string/from-bytes c))))))