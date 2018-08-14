// default actions to execute on all page loads
function enableDefaultActions() {
    $('.dropdown-toggle').dropdown();
    $('body').tooltip({selector: '[data-toggle="tooltip"]', container: 'body', trigger: 'hover'});
}

// set error state on blank text boxes or selects
function setErrorOnBlank(selector) {
    selector.map(function() {
        if ( $(this).val() === "" ) {
            $(this).parent().addClass('has-error has-feedback');
        } else {
            $(this).parent().removeClass('has-error has-feedback');
        }
    });
}

