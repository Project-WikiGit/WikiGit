import { Template } from 'meteor/templating'

import {DASP} from '../objects/dasp.js'

import './dasp_dashboard.html'

export DASP_Address = new String()

dasp = new DASP()

Template.repo_tab.helpers({
  file_list:
    () ->
      if dasp
        dasp.lsRepo('', (error, result) ->
          console.log(result)
        )
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