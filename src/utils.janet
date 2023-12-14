(def janet/print print)
(def janet/prin prin)
(def janet/pp pp)

(defn print [& args]
  (janet/print ;args)
  (file/flush (dyn :out stdout)))

(defn prin [& args]
  (janet/prin ;args)
  (file/flush (dyn :out stdout)))

(defn pp [& args]
  (janet/pp ;args)
  (file/flush (dyn :out stdout)))

(defn pn [& args]
  (janet/prin (string/format "%q" ;args))
  (file/flush (dyn :out stdout)))
