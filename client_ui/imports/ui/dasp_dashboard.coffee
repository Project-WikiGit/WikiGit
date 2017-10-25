import { Template } from 'meteor/templating'

import {ReactiveVar} from 'meteor/reactive-var'

import {DASP} from '../objects/dasp.js'

import './dasp_dashboard.html'

export DASP_Address = new ReactiveVar("")

dasp = new DASP()

current_file_list = new ReactiveVar([])

Template.repo_tab.helpers({
  ls_file:
    () ->
      return current_file_list.get()
})

Template.body.events({
  'submit .dasp_addr_input':
    (event) ->
      # Prevent default browser form submit
      event.preventDefault()

      # Get value from form element
      target = event.target
      text = target.dasp_addr.value

      DASP_Address.set(text)

      target.dasp_addr.value = ''

      dasp.initWithAddr(DASP_Address.get(), null, () ->
        dasp.lsRepo('', (error, result) ->
          current_file_list.set(result)
        )
      )
})