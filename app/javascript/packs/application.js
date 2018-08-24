/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb


import $ from 'jquery';
import jQuery from 'jquery';
import {Spinner} from 'spin.js';
import * as helpers from './helpers.js'

window.$ = $;
window.jQuery = jQuery;
window.Spinner = Spinner;
window.enableDefaultActions = helpers.enableDefaultActions;
window.elementVisible = helpers.elementVisible;
window.launchModalSpinner = helpers.launchModalSpinner;
window.closeModalSpinner = helpers.closeModalSpinner;
window.opts = helpers.opts;
window.OPEN_MODAL = helpers.OPEN_MODAL;
window.PAGE_RENDERED = helpers.PAGE_RENDERED;
