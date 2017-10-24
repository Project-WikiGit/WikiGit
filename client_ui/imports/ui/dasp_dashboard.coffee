import { Template } from 'meteor/templating'

import {DASP} from '../objects/dasp.js'

import './dasp_dashboard.html'

export DASP_Address = new String()

dasp = new DASP()

current_file_list = null #Todo: reactive var

Template.repo_tab.helpers({
  ls_file:
    (path) ->
      if dasp
        dasp.lsRepo(path, (error, result) ->
          current_file_list = result
        )
      return current_file_list
})

Template.body.events({
  'submit .dasp_addr_input':
    (event) ->
      # Prevent default browser form submit
      event.preventDefault()

      # Get value from form element
      target = event.target
      text = target.dasp_addr.value

      DASP_Address = text

      target.dasp_addr.value = ''

      dasp.initWithAddr(DASP_Address, null, () ->
        console.log(dasp.repoIPFSHash)
      )
})