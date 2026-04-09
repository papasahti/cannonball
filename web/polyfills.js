(function () {
  if (!Array.prototype.find) {
    Object.defineProperty(Array.prototype, 'find', {
      value: function (predicate, thisArg) {
        if (this == null) {
          throw new TypeError('Array.prototype.find called on null or undefined');
        }
        if (typeof predicate !== 'function') {
          throw new TypeError('predicate must be a function');
        }
        var list = Object(this);
        var length = list.length >>> 0;
        for (var index = 0; index < length; index += 1) {
          var value = list[index];
          if (predicate.call(thisArg, value, index, list)) {
            return value;
          }
        }
        return undefined;
      },
      configurable: true,
      writable: true,
    });
  }

  if (!Array.prototype.includes) {
    Object.defineProperty(Array.prototype, 'includes', {
      value: function (searchElement, fromIndex) {
        if (this == null) {
          throw new TypeError('Array.prototype.includes called on null or undefined');
        }
        var list = Object(this);
        var length = list.length >>> 0;
        if (length === 0) {
          return false;
        }
        var start = fromIndex | 0;
        var index = Math.max(start >= 0 ? start : length - Math.abs(start), 0);
        while (index < length) {
          if (list[index] === searchElement) {
            return true;
          }
          index += 1;
        }
        return false;
      },
      configurable: true,
      writable: true,
    });
  }

  if (!String.prototype.startsWith) {
    Object.defineProperty(String.prototype, 'startsWith', {
      value: function (search, position) {
        var start = position > 0 ? position | 0 : 0;
        return this.substring(start, start + search.length) === search;
      },
      configurable: true,
      writable: true,
    });
  }

  if (window.NodeList && !NodeList.prototype.forEach) {
    NodeList.prototype.forEach = function (callback, thisArg) {
      for (var index = 0; index < this.length; index += 1) {
        callback.call(thisArg, this[index], index, this);
      }
    };
  }
})();
