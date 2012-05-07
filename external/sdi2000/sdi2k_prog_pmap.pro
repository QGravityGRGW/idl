; >>>> begin comments
;==========================================================================================
;
; >>>> McObject Class: sdi2k_prog_pmap
;
; This file contains the McObject method code for sdi2k_prog_pmap objects:
;
; Mark Conde (Mc), Bromley, August 1999.
;
; >>>> end comments
; >>>> begin declarations
;         menu_name = Phase Mapper
;        class_name = sdi2k_prog_pmap
;       description = SDI Program - Phase Map
;           purpose = SDI operation
;       idl_version = 5.2
;  operating_system = Windows NT4.0 terminal server 
;            author = Mark Conde
; >>>> end declarations


;==========================================================================================
; This is the (required) "new" method for this McObject:

pro sdi2k_prog_pmap_new, instance, dynamic=dyn, creator=cmd
;---First, properties specific to this object:
    cmd = 'instance = {sdi2k_prog_pmap, '
    cmd = cmd + 'specific_cleanup: ''sdi2k_prog_pmap_specific_cleanup'', '    
;---Now add fields common to all SDI objects. These will be grouped as sub-structures:
    sdi2k_common_fields, cmd, automation=automation, geometry=geometry
;---Next, add the required fields, whose specifications are read from the 'declarations'
;   section of the comments at the top of this file:
    whoami, dir, file    
    obj_reqfields, dir+file, cmd, dynamic=dyn
;---Now, create the instance:
    status = execute(cmd)
end

;==========================================================================================
; This is the event handler for events generated by the sdi2k_prog_pmap object:
pro sdi2k_prog_pmap_event, event
    widget_control, event.top, get_uvalue=info
    wid_pool, 'Settings: ' + info.wtitle, widx, /get
    if not(widget_info(widx, /valid_id)) then return
    widget_control, widx, get_uvalue=pmap_settings
    if widget_info(event.id, /valid_id) and pmap_settings.automation.show_on_refresh then widget_control, event.id, /show

;---Check for a timer tick:    
    if tag_names(event, /structure_name) eq 'WIDGET_TIMER' then begin
       sdi2k_prog_pmap_tik, info.wtitle
       if pmap_settings.automation.timer_ticking then widget_control, widx, timer=pmap_settings.automation.timer_interval
       return
    endif
    
;---Check for a new frame event sent by the control module:
    nm      = 0
    matched = where(tag_names(event) eq 'NAME', nm)
    if nm gt 0 then begin
       if event.(matched(0)) eq 'NewFrame' then begin
          sdi2k_prog_pmap_tik, info.wtitle
          return
       endif
       if event.(matched(0)) eq 'Integration Completed' then begin
          sdi2k_prog_pmap_integration_done, info.wtitle
          return
       endif
    endif

;---Get the menu name for this event:
    widget_control, event.id, get_uvalue=menu_item
    if n_elements(menu_item) eq 0 then menu_item = 'Nothing valid was selected'
end

;==========================================================================================
; This is the routine that updates the phase accumulations:
pro sdi2k_prog_pmap_tik, wtitle, redraw=redraw, _extra=_extra
@sdi2kinc.pro
    common pmap_stuff, pmap_discards

;---Get settings information for this instance of the output xwindow and this instance of 
;   the plot program itself:
    wid_pool, wtitle, widx, /get
    if not(widget_info(widx, /valid_id)) then return
    widget_control, widx, get_uvalue=info
    wid_pool, 'Settings: ' + wtitle, sidx, /get
    if not(widget_info(sidx, /valid_id)) then return
    widget_control, sidx, get_uvalue=pmap_settings
    
    pmap_discards = pmap_discards + 1
    if pmap_discards lt 3 then return
    
;---Save the phase angle corresponding to the etalon scan setting during the 
;   previous frame, i.e., during the frame that we have only just now received:
    angle = (host.hardware.etalon.current_spacing - host.hardware.etalon.start_spacing) * $
             host.programs.phase_map.angle_coefficient
;---Next, get the etalon moved on to the next spacing, as the CCD has already started
;   exposing the next frame, and we want the etalon scanned for it asap:
    if !d.name ne 'Z' and !d.name ne 'PS' then begin
        wset, info.wid
        sdi2k_etalon_scan, lambda=host.operation.calibration.cal_wavelength
    endif

    phasex = phasex + view*cos(angle)
    phasey = phasey + view*sin(angle)
    
;---If we have just finished a scan, update the pmap, and check for end time:
    if host.hardware.etalon.current_channel eq 0 then begin
       phase = atan(phasey, phasex)
       tv, host.colors.imgmin + bytscl(phase, top=host.colors.imgmax - host.colors.imgmin - 2)
;------Test for end of exposure:
       if dt_tm_tojs(systime()) - host.programs.phase_map.start_time gt $
          host.programs.phase_map.integration_seconds then begin
;---------Make a GIF of the final phase map (if gif-ing is active):
          sdi2k_plugin_gif, info, /now
          wid_pool, 'sdi2k_top', tidx, /get
          if !d.name ne 'Z' and !d.name ne 'PS' then $
              widget_control, sidx, send_event={id: tidx, $
                                               top: tidx, $
                                           handler: sidx, $
                                              name: 'Integration Completed'}
       endif
    endif

;---Finally, update the exposure meter, if it exists:
    wid_pool, 'SDI Program - Exposure: Phase Map', eidx, /get
    wid_pool, 'pmap_exposure_slider', slid, /get

    if not(widget_info(eidx, /valid_id)) then return
    delsecs = dt_tm_tojs(systime()) - host.programs.phase_map.start_time
    pcnt    = 100.*delsecs/host.programs.phase_map.integration_seconds
    widget_control, slid, get_value=opc
    if pcnt - opc gt 2 then widget_control, slid, set_value=pcnt

end

;==========================================================================================
;   End of phase map integration: save the phase map to a file, and exit:
pro sdi2k_prog_pmap_integration_done, wtitle
@sdi2kinc.pro
    pfile = sdi2k_filename(host.programs.phase_map.file_prefix)
    sdi2k_user_message, 'Phase mapping done. Writing file: ' + pfile
    pmap_host = host
    pmap_host.programs.phase_map.integration_seconds = dt_tm_tojs(systime()) - host.programs.phase_map.start_time
    save, phase, pmap_host, filename=pfile
    wid_pool, wtitle, widx, /destroy
end

;==========================================================================================
;   Cleanup jobs:
pro sdi2k_prog_pmap_specific_cleanup, widid
@sdi2kinc.pro
    host.controller.scheduler.job_semaphore = 'No scheduled job'
    sdi2k_set_shutters, camera='closed', laser='closed'
end

pro sdi2k_prog_pmap_end_expmeter
@sdi2kinc.pro
    wid_pool, 'SDI Program - Exposure: Phase Map', /destroy
end


;==========================================================================================
; This is the (required) "autorun" method for this McObject. If no autorun action is 
; needed, then this routine should simply exit with no action:

pro sdi2k_prog_pmap_autorun, instance
@sdi2kinc.pro
    common pmap_stuff, pmap_discards
    
    phase       = bytarr(n_elements(view(*,0)), n_elements(view(0,*)))
    phasex      = fltarr(n_elements(view(*,0)), n_elements(view(0,*)))
    phasey      = fltarr(n_elements(view(*,0)), n_elements(view(0,*)))                     
    wid_pool, 'SDI program - Phase Map', /destroy
    host.programs.phase_map.angle_coefficient = 2.*!pi*host.hardware.etalon.nm_per_step * $
                                                host.hardware.etalon.gap_refractive_index / $
                                               (host.operation.calibration.cal_wavelength/2.)
    instance.geometry.xsize = n_elements(view(*,0))
    instance.geometry.ysize = n_elements(view(0,*))
    instance.automation.timer_interval = 1.
    instance.automation.timer_ticking = 0
    instance.automation.auto_gif_interval = 9999999l    
    
    sdi2k_set_shutters, camera='open', laser='closed'
    status = sdi2k_filter_interface(command='2 mv')
    sdi2k_etalon_scan, /reset
    pmap_discards = 0
    host.controller.scheduler.job_semaphore = 'Acquiring a phase map'
    host.programs.phase_map.start_time = dt_tm_tojs(systime())
    mnu_xwindow_autorun, instance, topname='sdi2k_top'
    
;---Return if we already have an instance running:
    wid_pool, 'SDI Program - Exposure: Phase Map', widx, /get
    if widget_info(widx, /valid_id) then begin
       return
    endif

;---Create the exposure meter:
    wtitle = 'SDI Program - Exposure: Phase Map'
    wid_pool, 'sdi2k_top', widx, /get
    wid_pool, instance.description, sidx, /get
    top = WIDGET_BASE(title=wtitle, /column, group=sidx)
    expmet = widget_slider(top, xsize=280, title="Exposure Percent")
;---Register the plot xwindow name and top-level widget index with "wid_pool":
    wid_pool, 'pmap_exposure_slider', expmet, /add
    wid_pool, 'SDI Program - Exposure: Phase Map', top, /add
    widget_control, top, /realize
    widget_control, top, set_uvalue={s_expm, wtitle: wtitle}
end

;==========================================================================================
; This is the (required) class method for creating a new instance of the sdi2k_prog_pmap object. It
; would normally be an empty procedure.  Nevertheless, it MUST be present, as the last procedure in 
; the methods file, and it MUST have the same name as the methods file.  By calling this
; procedure, the caller forces all preceeding routines in the methods file to be compiled, 
; and so become available for subsequent use:

pro sdi2k_prog_pmap
end
