(import ./journo :prefix "" :export true)

# The following `setdyn`s manually remove certain bindings
# from the imported environment table. This is equivalent
# to marking the bindings below as `:private`, but with
# the advantage of still being able to `import` them for
# testing purposes.
#
# This would be unnecessary if Janet could selectively
# import bindings from modules.

(setdyn 'cleanup-rawterm nil)
(setdyn 'collect-answer nil)
(setdyn 'collect-choices nil)
(setdyn 'collect-text-input nil)
(setdyn 'cursor-go-to-pos nil)
(setdyn 'gather-multi-byte-input nil)
(setdyn 'get-cursor-pos nil)
(setdyn 'handle-resize nil)
(setdyn 'render-options nil)
(setdyn 'set-size nil)
(setdyn 'unwind-choices nil)