;(function (root) {
    'use strict'

    var Yaku = function Yaku (executor) {

    }, proto = Yaku.prototype

    proto.then = function (onFulfilled, onRejected) {

    }

    proto['catch'] = function (onRejected) {
        this.then($nil, onRejected)
    }

// ********************** Private **********************
    /**
     * All static variable name will begin with `$`. Such as `$rejected`.
     * @private
     */

    // ******************************* Utils ********************************

    var $nil = void 0,
    , $noop = {}
    , $tryCatchFn

    // CMD & AMD Support
    try {
        module.exports = Yaku
    }
    catch (e) {
        try {
            define(function () { return Yaku })
        }
        catch (e) {
            root.Yaku = Yaku
        }
    }

})(this || window);