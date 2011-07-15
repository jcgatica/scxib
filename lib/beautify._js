(function (src)
{
    try
    {
        var ast = jsp.parse(src);
        print(uglify.gen_code(ast, { indent_level: 2 }));
    }
    catch (ex)
    {
        debug(ex.toString());
        debug("Use -debug option to see pre-beautified JavaScript result");
    }
})(arguments[0]);
