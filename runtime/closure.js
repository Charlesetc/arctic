
function _closure(name, arguments, types) {

  this.name = name;
  this.arguments = arguments;
  this.types = types;

  this.partial = function(argument, type) {
    return new _closure(
      this.name,
      this.arguments.concat(argument),
      this.types.concat([type])
    );
  };

  this.call = function() {
    // strange way to deal with units...
    if (this.arguments[this.arguments.length-1] == null) {
      this.arguments.pop();
      this.types.pop();
    }
    return global_functions
      [this.name]
      [this.types.join()]
      .apply(null, this.arguments);
  };

}

function new_closure(name, ...closed) {
  return  new _closure(name, closed, []);
}

const __unit = null
