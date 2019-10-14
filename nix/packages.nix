{ }:
let inherit (builtins) typeOf trace attrNames toString;
in {
  pp = v:
    let type = typeOf v;
    in if type == "list" then
      trace (toString v) v
    else if type == "set" then
      trace (toString (attrNames v)) v
    else
      trace (toString v) v;
}
