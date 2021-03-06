; >>>> begin comments
;==========================================================================================
;
; >>>> McObject Class: sdi2k_prog_pshf
;
; This file contains the McObject method code for sdi2k_prog_pshf objects:
;
; Mark Conde Fairbanks, October 2000.
;
; >>>> end comments
; >>>> begin declarations
;         menu_name = Phase Map Wavelength Shift
;        class_name = sdi2k_prog_pshf
;       description = SDI Program - Phase Map Wavelength Shift
;           purpose = SDI operation
;       idl_version = 5.2
;  operating_system = Windows NT4.0 terminal server 
;            author = Mark Conde
; >>>> end declarations


;==========================================================================================
; This is the (required) "new" method for this McObject:

pro sdi2k_prog_pshf_new, instance, dynamic=dyn, creator=cmd
;---First, properties specific to this object:
    cmd = 'instance = {sdi2k_prog_pshf, '
    cmd = cmd + 'tick_count: 0, '    
    cmd = cmd + 'specific_cleanup: ''sdi2k_prog_pshf_specific_cleanup'', '    
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
; This is the event handler for events generated by the sdi2k_prog_pshf object:
pro sdi2k_prog_pshf_event, event
    widget_control, event.top, get_uvalue=info
    wid_pool, 'Settings: ' + info.wtitle, widx, /get
    if not(widget_info(widx, /valid_id)) then return
    widget_control, widx, get_uvalue=pshf_settings
    if widget_info(event.id, /valid_id) and pshf_settings.automation.show_on_refresh then widget_control, event.id, /show

;---Check for a timer tick:    
    if tag_names(event, /structure_name) eq 'WIDGET_TIMER' then begin
       sdi2k_prog_pshf_tik, info.wtitle
       if pshf_settings.automation.timer_ticking then begin
          if widget_info(widx, /valid) then widget_control, widx, timer=pshf_settings.automation.timer_interval
       endif 
       return
    endif
    
;---Check for a new frame event sent by the control module:
    nm      = 0
    matched = where(tag_names(event) eq 'NAME', nm)
    if nm gt 0 then begin
       if event.(matched(0)) eq 'NewFrame' then sdi2k_prog_pshf_tik, info.wtitle
       return
    endif

;---Get the menu name for this event:
    widget_control, event.id, get_uvalue=menu_item
    if n_elements(menu_item) eq 0 then menu_item = 'Nothing valid was selected'
end

;==========================================================================================
; This is the routine that updates the actual plot:
pro sdi2k_prog_pshf_tik, wtitle, redraw=redraw, _extra=_extra
@sdi2kinc.pro

;---Get settings information for this instance of the output xwindow and this instance of 
;   the plot program itself:
    wid_pool, wtitle, widx, /get
    if not(widget_info(widx, /valid_id)) then return
    widget_control, widx, get_uvalue=info
    wid_pool, 'Settings: ' + wtitle, sidx, /get
    if not(widget_info(sidx, /valid_id)) then return
    widget_control, sidx, get_uvalue=pshf_settings

    pshf_settings.tick_count = pshf_settings.tick_count + 1

    if n_elements(phase) gt 0 then begin
       tv, host.colors.imgmin + bytscl(phase, top=host.colors.imgmax - host.colors.imgmin - 2, $
                                       min=0, max=2*!pi)
       xyouts, 0.5, 0.8, "Shifted phase map", /normal, color=host.colors.white, align=0.5, charsize=1.8, charthick=2
    endif
    widget_control, sidx, set_uvalue=pshf_settings
end

;==========================================================================================
;   Cleanup jobs:
pro sdi2k_prog_pshf_specific_cleanup, widid
@sdi2kinc.pro
end

pro sdi2k_pshf_shiftmap, wtitle
@sdi2kinc.pro
    wid_pool, wtitle, widx, /get
    if not(widget_info(widx, /valid_id)) then return
    widget_control, widx, get_uvalue=info
    wid_pool, 'Settings: ' + wtitle, sidx, /get
    if not(widget_info(sidx, /valid_id)) then return
    widget_control, sidx, get_uvalue=pshf_settings
    
    if !d.name ne 'Z' and !d.name ne 'PS' then wset, info.wid
    tv, host.colors.imgmin + bytscl(phase-min(phase), top=host.colors.imgmax - host.colors.imgmin - 2, $
                                    min=0, max=host.hardware.etalon.scan_channels)
    xyouts, 0.5, 0.8, "Removing discontinuities", /normal, color=host.colors.white, align=0.5, charsize=1.8, charthick=2
    
;   Make an image array whose elements represent the distance from the nominal fringe center:
    nx   = n_elements(view(*,0))
    ny   = n_elements(view(0,*))
    xx   = transpose(lindgen(ny,nx)/ny) - host.operation.zones.x_center
    yy   = lindgen(nx,ny)/nx            - host.operation.zones.y_center
    dst  = xx*xx + yy*yy
    dord = sort(dst)
    pscl = (host.colors.imgmax - host.colors.imgmin)/float(host.hardware.etalon.scan_channels*host.programs.phase_shift.display_orders)
    dcnt = 0
    for j=1l,n_elements(dord)-1 do begin
        jlo = ((j - host.programs.phase_shift.radial_chunk) > (0))
        phase_here = total(phase(dord(jlo:j)))/(j-jlo)
        while phase_here - phase(dord(j)) gt host.programs.phase_shift.order_step do $
              phase(dord(j)) = phase(dord(j)) + host.hardware.etalon.scan_channels
        tv, [host.colors.imgmin+ phase(dord(j))*pscl], $
            xx(dord(j)) + host.operation.zones.x_center, $
            yy(dord(j)) + host.operation.zones.y_center
;-------Insert some short waits, to allow the program to be cancelled:
        dcnt = dcnt + 1
        if dcnt gt 500 then begin
           dcnt = 0
           wait, 0.05
        endif
    endfor
;    phase = mc_im_sm(phase, host.programs.phase_shift.smoothing)
    phase    = mc_im_sm(phase, 3)
    l4       = phase
    tv, host.colors.imgmin + bytscl(phase, top=host.colors.imgmax - host.colors.imgmin - 2, $
                                    min=0, max=127*host.programs.phase_shift.display_orders)    
    xyouts, 0.5, 0.8, "Smoothed phase!C function", /normal, color=host.colors.white, align=0.5, charsize=1.8, charthick=2
    wait, 5

goto, NO_CORR    

;restore, 'D:\USERS\sdi2000\data\phl4_unwrapped2002070.pf'
;l4 = phase
restore, 'D:\USERS\sdi2000\data\phn4_unwrapped2002080.pf'
n4 = phase
restore, 'D:\USERS\sdi2000\data\phn1_unwrapped2002080.pf'
n1 = phase

n4 = mc_im_sm(n4, 3)
n1 = mc_im_sm(n1, 3)
l4 = mc_im_sm(l4, 3)

epsilon = n1 - n4

dpix    = 3
dn4dx   = (shift(n4, dpix, 0) - n4)/dpix
dn4dy   = (shift(n4, 0, dpix) - n4)/dpix

sqgrad  = dn4dx^2 + dn4dy^2 + 0.001

delx    = epsilon*dn4dx/sqgrad
dely    = epsilon*dn4dy/sqgrad

dl4dx   = (shift(l4, dpix, 0) - l4)/dpix
dl4dy   = (shift(l4, 0, dpix) - l4)/dpix

lgamma  = delx*dl4dx + dely*dl4dy
lgamma  = lgamma < 70
lgamma  = lgamma > (-70)

;stop
;tv, l4
;wait, 2

;shade_surf, delx(20:220, 40:300)
;wait, 2
;shade_surf, lgamma(20:220, 40:300)
;wait, 2

phase  = l4 + lgamma

NO_CORR:
    if host.operation.calibration.sky_wavelength eq 0. then scale = 1. else $
       scale = host.operation.calibration.cal_wavelength/host.operation.calibration.sky_wavelength
    lophase  = min(phase)
    phase    = scale*(phase - lophase)


;       phase    = phase - min(phase)
;       pfile = sdi2k_filename('phn4_unwrapped')
;       pmap_host = host
;       save, phase, pmap_host, filename=pfile

    phase    = phase mod host.hardware.etalon.scan_channels
    tv, host.colors.imgmin + bytscl(phase, top=host.colors.imgmax - host.colors.imgmin - 2, $
                                    min=0, max=host.hardware.etalon.scan_channels)
    xyouts, 0.5, 0.8, "Scaled phase map", /normal, color=host.colors.white, align=0.5, charsize=1.8, charthick=2
    phase = phase*2*!pi/host.hardware.etalon.scan_channels
end

;==========================================================================================
; This is the (required) "autorun" method for this McObject. If no autorun action is 
; needed, then this routine should simply exit with no action:

pro sdi2k_prog_pshf_autorun, instance
@sdi2kinc.pro
    instance.geometry.xsize = n_elements(view(*,0))
    instance.geometry.ysize = n_elements(view(0,*))
    instance.automation.timer_interval = 2.
    instance.automation.timer_ticking = 0
    instance.automation.auto_gif_interval = 9999999l

    mnu_xwindow_autorun, instance, topname='sdi2k_top'
    wid_pool, instance.description, widx, /get
    
    if host.programs.phase_shift.prompt_for_filename then begin
       mapfile = dialog_pickfile(file=sdi2k_filename(host.programs.phase_map.file_prefix), $
                                 filter=host.programs.phase_map.file_prefix + '*.' + host.operation.header.site_code, $
                                 group=widx, title='Select a phase map file: ', $
                                 path=host.operation.logging.log_directory)                                 
    endif else mapfile = sdi2k_filename(host.programs.phase_map.file_prefix)
    
    if fexist(mapfile) then begin
       sdi2k_load_phase_map, mapfile
       sdi2k_pshf_shiftmap, instance.description
;------Save the shifted phase map:
       pfile = sdi2k_filename(host.programs.phase_shift.file_prefix)
       sdi2k_user_message, 'Phase shifting done. Writing file: ' + pfile
       pmap_host = host
       save, phase, pmap_host, filename=pfile
    endif else wid_pool, instance.description, widx, /destroy
    if host.programs.phase_shift.exit_on_completion then wid_pool, instance.description, widx, /destroy
end

;==========================================================================================
; This is the (required) class method for creating a new instance of the sdi2k_prog_pshf object. It
; would normally be an empty procedure.  Nevertheless, it MUST be present, as the last procedure in 
; the methods file, and it MUST have the same name as the methods file.  By calling this
; procedure, the caller forces all preceeding routines in the methods file to be compiled, 
; and so become available for subsequent use:

pro sdi2k_prog_pshf
end

