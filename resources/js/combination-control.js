var CombinationController = (function () {
    
        // Constructor
        function CombinationController ($cont, idx) {
            function group (members, x_move, y_move) {
                this.members = members;
                this.x_move = x_move;
                this.y_move = y_move;
            }
            var scroll_version_id;
            var artefacts = [];
            var zoom_factor = 0.05;
            var max_zoom = 0.1;
            var scroll_dpi = 1215;
            var scroll_width = 50000;
            var scroll_height = 5000;
            var $comb_scroll = $('<div ondragstart="return false;"></div>');
            $comb_scroll.attr('id','combination-viewport');
            $comb_scroll.css('width', (scroll_width * zoom_factor) + 'px');
            $comb_scroll.css('height', (scroll_height * zoom_factor) + 'px');
            $comb_scroll.css('overflow', 'hidden');
            $('#combination-pane').append($comb_scroll);
            var $container = $cont;
            var $zoom_control = $('<input>');
            $zoom_control.attr('type', "range")
            .attr('id', "combination-zoom-slider")
            .attr('min', '0.01')
            .attr('max', '0.4')
            .attr('step', '0.001')
            .attr('value', '0.05')
            .on("input", function(){
                zoom(this.value, true);
            })
            .on("change", function(){
                zoom(this.value, false);
            });
            $container.append($zoom_control);
            var focused_element = undefined;
            var self = this;
    
            // Private functions, will be invoked by name.call(this, ...input vars)
            function load_scroll(id, scroll_version){
                $comb_scroll.empty();
                var $osd = $('<div></div>');
                $osd.attr('id', 'combination_osd');
                $osd.attr('class', 'comb_osd');
                $osd.css('visibility', 'hidden');
                $osd.css('position', 'absolute');
                $osd.css('top', '50%');
                $osd.css('left', '50%');
                $osd.css('margin-left', '-20px');
                $osd.css('margin-top', '-20px');
                $osd.css('display', 'block');
                $osd.prepend('<img id="osd_rotate" class="rotate_handle" width="40" height="40" src="resources/images/rotate.png" style="pointer-events: auto"/>');
                $comb_scroll.append($osd);
                scroll_version_id = scroll_version;

                var scroll_data = new FormData();
                scroll_data.append('transaction', 'getScrollWidth');
                scroll_data.append('scroll_id', id);
                scroll_data.append('scroll_version_id', scroll_version_id);
                scroll_data.append('SESSION_ID', Spider.session_id);
                jQuery.ajax({
                    url: 'resources/cgi-bin/GetImageData.pl',
                    context: this,
                    data: scroll_data,
                    cache: false,
                    contentType: false,
                    processData: false,
                    type: 'POST',
                    success: function(selected_artefacts){
                        selected_artefacts['results'].forEach(function(artefact){
                            scroll_width = artefact.max_x;
                            $comb_scroll.css('width', (artefact.max_x * zoom_factor) + 'px');

                            scroll_data = new FormData();
                            scroll_data.append('transaction', 'getScrollHeight');
                            scroll_data.append('scroll_id', id);
                            scroll_data.append('scroll_version_id', scroll_version_id);
                            scroll_data.append('SESSION_ID', Spider.session_id);
                            jQuery.ajax({
                                url: 'resources/cgi-bin/GetImageData.pl',
                                context: this,
                                data: scroll_data,
                                cache: false,
                                contentType: false,
                                processData: false,
                                type: 'POST',
                                success: function(selected_artefacts){
                                    selected_artefacts['results'].forEach(function(artefact){
                                        scroll_height = artefact.max_y
                                        $comb_scroll.css('height', (artefact.max_y * zoom_factor) + 'px');

                                        scroll_data = new FormData();
                                        scroll_data.append('transaction', 'getScrollArtefacts');
                                        scroll_data.append('scroll_id', id);
                                        // scroll_data.append('user_id', Spider.user_id);
                                        // scroll_data.append('version', Spider.current_version);
                                        scroll_data.append('scroll_version_id', scroll_version_id);
                                        scroll_data.append('SESSION_ID', Spider.session_id);
                                        jQuery.ajax({
                                            url: 'resources/cgi-bin/GetImageData.pl',
                                            context: this,
                                            data: scroll_data,
                                            cache: false,
                                            contentType: false,
                                            processData: false,
                                            type: 'POST',
                                            success: function(selected_artefacts){
                                                selected_artefacts['results'].forEach(function(artefact) {
                                                    var x_loc = parseFloat(artefact.pos.split(' ')[0].replace('POINT(', ''));
                                                    var y_loc = parseFloat(artefact.pos.split(' ')[1]);
                                                    var data = artefact['poly'];
                                                    var polygons = data.split("\),\(");
                                                    var rect = artefact.rect;
                                                    rect = rect.replace('POLYGON((', '');
                                                    var coords = rect.split(',');
                                                    var img_x = coords[0].split(' ')[0];
                                                    var img_y = coords[0].split(' ')[1];
                                                    var img_width = coords[2].split(' ')[0] - img_x;
                                                    var img_height = coords[2].split(' ')[1] - img_y;
                                                    var img_rotation = artefact.rotation;
                                                    var new_polygons = '';
                                                    polygons.forEach(function(polygon, index) {
                                                        new_polygons += 'M';
                                                        polygon = polygon.replace(/POLYGON/g, "");
                                                        polygon = polygon.replace(/\(/g, "");
                                                        polygon = polygon.replace(/\)/g, "");
                                                        var points = polygon.split(",");
                                                        points.forEach(function(point) {
                                                            if (new_polygons.slice(-1) !== 'M'){
                                                                new_polygons += 'L';
                                                            }
                                                            new_polygons += (point.split(' ')[0] - img_x) + ' ' + (point.split(' ')[1] - img_y);
                                                        }, this);
                                                    }, this);
                            
                                                    var image_cont_xy = document.createElement('div');
                                                    image_cont_xy.setAttribute('id', 'image-cont-xy-' + artefact['id']);
                                                    image_cont_xy.setAttribute('class', 'fragment fragment-cont-xy');
                                                    $(image_cont_xy).css({transform: 'initial'});
                            
                                                    var image_cont_rotate = document.createElement('div');
                                                    image_cont_rotate.setAttribute('id', 'image-cont-rotate-' + artefact['id']);
                                                    image_cont_rotate.setAttribute('class', 'fragment fragment-cont-rot');
                                                    image_cont_rotate.setAttribute('data-rotate', img_rotation);
                            
                                                    var image = document.createElementNS("http://www.w3.org/2000/svg", "svg");
                                                    image.setAttribute('id', 'SVG-' + artefact['id']);
                                                    
                                                    var pathDefs = document.createElementNS("http://www.w3.org/2000/svg", "defs");
                                                    path = document.createElementNS("http://www.w3.org/2000/svg", "path");
                                                    path.setAttribute('id', 'Path-' + artefact['id']);
                                                    
                                                    var clipPathDefs = document.createElementNS("http://www.w3.org/2000/svg", "defs");
                                                    clipPath = document.createElementNS("http://www.w3.org/2000/svg", "clipPath");
                                                    clipPath.setAttribute('id', 'Clip-' + artefact['id']);
                                                    var clipPathPath = document.createElementNS("http://www.w3.org/2000/svg", "use");
                                                    clipPathPath.setAttribute('stroke', 'none');
                                                    clipPathPath.setAttribute('fill', 'black');
                                                    clipPathPath.setAttribute('fill-rule', 'evenodd');
                                                    clipPathPath.setAttributeNS("http://www.w3.org/1999/xlink", 'xlink:href', '#Path-' + artefact['id']);
                                                    
                                                    var imgContainer = document.createElementNS("http://www.w3.org/2000/svg", "g");
                                                    imgContainer.setAttribute('id', 'Container-' + artefact['id']);
                                                    imgContainer.setAttribute('clip-path', 'url(#' + 'Clip-' + artefact['id'] + ')');
                                                    imgContainer.setAttribute('pointer-events', 'visiblePainted');
                                                    var svgImage = document.createElementNS("http://www.w3.org/2000/svg", "image");
                                                    svgImage.setAttribute('id', 'ClippedImg-' + artefact['id']);
                                                    svgImage.setAttribute('class', 'clippedImg');
                                                    svgImage.setAttribute('draggable', 'false');
                                                    
                                                    var outline = document.createElementNS("http://www.w3.org/2000/svg", "use");
                                                    outline.setAttribute('stroke', 'blue');
                                                    outline.setAttribute('stroke-width', '3');
                                                    outline.setAttribute('fill', 'none');
                                                    outline.setAttribute('fill-rule', 'evenodd');
                                                    outline.setAttribute('id', 'fragOutline-' + artefact['id']);
                                                    outline.setAttribute('class', 'fragOutline');
                                                    outline.setAttributeNS("http://www.w3.org/1999/xlink", 'xlink:href', '#Path-' + artefact['id']);
                                                    
                                                    pathDefs.appendChild(path);
                                                    clipPath.appendChild(clipPathPath);
                                                    clipPathDefs.appendChild(clipPath);
                                                    imgContainer.appendChild(svgImage);
                                                    image.appendChild(pathDefs);
                                                    image.appendChild(clipPathDefs);
                                                    image.appendChild(imgContainer);
                                                    image.appendChild(outline);
                            
                                                    var artefact_dpi = artefact.dpi;
                                                    var scale = (scroll_dpi / artefact_dpi) * zoom_factor; //I may have a problem with the math here
                                                    path.setAttribute('d', new_polygons);
                                                    path.setAttribute('transform', 'scale(' + scale + ')');
                                                    svgImage.setAttributeNS("http://www.w3.org/1999/xlink", 'xlink:href', "https://134.76.19.179/cgi-bin/sqe-iiif.pl?user=" + Spider.user + "&url=" + artefact.url + "&file="
                                                      + artefact.filename + '/' + img_x + ',' + img_y + ',' + img_width + ',' + img_height + '/pct:' + (scale * 100 < 100 ? scale * 100 : 100) + '/0/' + artefact.suffix);
                                                    svgImage.setAttribute('class', 'clippedImg');
                                                    svgImage.setAttribute('width', img_width * scale);
                                                    svgImage.setAttribute('height', img_height * scale);
                                                    image.setAttribute('width', img_width * scale);
                                                    image.setAttribute('height', img_height * scale);
                                                    artefacts.push({'path': path, 'image':svgImage, 'container': image, 'width': img_width, 'height': img_height, 'dpi': artefact_dpi, 'url': artefact.url, 'filename': artefact.filename, 'crop_x': img_x, 'crop_y': img_y, 'crop_width': img_width, 'crop_height': img_height, 'suffix': artefact.suffix});
                            
                                                    image_cont_rotate.appendChild(image);
                                                    image_cont_xy.appendChild(image_cont_rotate);
                                                    image_cont_xy.dataset.x_loc = x_loc;
                                                    image_cont_xy.dataset.y_loc = y_loc;
                                                    $(image_cont_xy).css({
                                                        top: y_loc * zoom_factor,
                                                        left: ((scroll_width - x_loc) * zoom_factor) - (img_width * scale)});
                                                    $(image_cont_rotate).css('transform', 'rotate(' + img_rotation + 'deg)');
                                                    $comb_scroll.append($(image_cont_xy));
                                                }, this);
                                            }
                                        });
                                    });
                                }
                            });
                        });
                    }
                });

                //Event handling
                var start_angle = 0;
                $comb_scroll.off('mousedown');
                $comb_scroll.off('mousemove');

                $comb_scroll.on('mousemove', mousehover);

                $comb_scroll.on('mousedown', mouseDown);
                var mouseOrigin = {x: 0, y: 0};
                var selected_artefact;
                function mouseDown(evt) {
                    if (evt.target !== evt.currentTarget) {
                        if($(evt.target).attr("class") === 'clippedImg'){
                            evt.preventDefault();
                            $comb_scroll.off('mousedown', mouseDown);
                            $comb_scroll.off('mousemove', mousehover);
                            if (Spider.unlocked){
                                selected_artefact = evt.target;
                                $comb_scroll.on('mousemove', mouseMove);
                                $comb_scroll.on('mouseup', mouseUp);
                                $comb_scroll.append($(evt.target).parent().parent().parent().parent());
                                mouseOrigin.x = evt.clientX;
                                mouseOrigin.y = evt.clientY;
                                evt.stopPropagation();
                            } 
                        } else if($(evt.target).attr("class") === 'rotate_handle'){
                            if (Spider.unlocked){
                                selected_artefact = evt.target;
                                evt.preventDefault();
                                var domRect = evt.target.getBoundingClientRect();
                                var cx = domRect.left + (domRect.width/2);
                                var cy = domRect.top + (domRect.height/2);
                                var frag_rot = $(evt.target).parent().parent().data('rotate');
                                start_angle = angle(cx, cy, evt.pageX, evt.pageY) - frag_rot;
                                $comb_scroll.off('mousedown', mouseDown);
                                $comb_scroll.off('mousemove', mousehover);
                                $comb_scroll.on('mousemove', rotateMove);
                                $comb_scroll.on('mouseup', rotateUp);
                            }
                        }
                    }
                }

                function rotateMove(evt) {
                    var domRect = selected_artefact.getBoundingClientRect();
                    var cx = domRect.left + (domRect.width/2);
                    var cy = domRect.top + (domRect.height/2);
                    var rot_angle = angle(cx, cy, evt.pageX, evt.pageY) - start_angle;
                    $(selected_artefact).parent().parent().css('transform', 'rotate(' + rot_angle + 'deg)')
                }

                function rotateUp(evt) {
                    var domRect = selected_artefact.getBoundingClientRect();
                    var cx = domRect.left + (domRect.width/2);
                    var cy = domRect.top + (domRect.height/2);
                    var rot_angle = angle(cx, cy, evt.pageX, evt.pageY) - start_angle;
                    rot_angle = rot_angle < 0 ? 360 + rot_angle : rot_angle;
                    start_angle = 0;
                    var $frag_cont = $(selected_artefact).parent().parent().parent();
                    $(selected_artefact).parent().parent().data('rotate', rot_angle);
                    selected_artefact = undefined;
                    $comb_scroll.off('mousemove', rotateMove);
                    $comb_scroll.off('mouseup', rotateUp);
                    var scroll_data = new FormData();
                    scroll_data.append('transaction', 'setArtRotation');
                    scroll_data.append('scroll_id', Spider.current_combination);
                    scroll_data.append('version', Spider.current_version);
                    scroll_data.append('version_id',scroll_version_id);
                    scroll_data.append('art_id', $frag_cont.attr("id").split("image-cont-xy-")[1]);
                    scroll_data.append('rotation', rot_angle);
                    scroll_data.append("SESSION_ID", Spider.session_id);
                    jQuery.ajax({
                        url: 'resources/cgi-bin/GetImageData.pl',
                        context: this,
                        data: scroll_data,
                        cache: false,
                        contentType: false,
                        processData: false,
                        type: 'POST',
                        success: function(selected_artefacts){
                            stopFragSelect();
                            $frag_cont.attr("id", "image-cont-xy-" + selected_artefacts.returned_info);
                            $comb_scroll.on('mousedown', mouseDown);
                            $comb_scroll.on('mousemove', mousehover);
                        }
                    });
                }
                
                function angle(cx, cy, ex, ey) {
                    var dy = cy - ey;
                    var dx = ex - cx;
                    return Math.atan2(dx, dy) * 180 / Math.PI;
                    }

                function mousehover(evt) {
                    if (!focused_element) {
                        if($(evt.target).attr("class") === 'clippedImg'){
                            evt.preventDefault();
                            if (Spider.unlocked){
                                focused_element = evt.target;
                                $(focused_element).parent().css('opacity', 0.85);
                                $(focused_element).parent().next().css('visibility', 'visible');
                                $(focused_element).parent().parent().parent().prepend($osd);
                                $osd.css('visibility', 'visible');
                                $comb_scroll.append($(focused_element).parent().parent().parent().parent());
                            }
                            evt.stopPropagation();
                        }
                    } else {
                        if(evt.target !== focused_element && $(evt.target).attr("class") !== 'rotate_handle'){
                            evt.preventDefault();
                            if (Spider.unlocked){
                                stopFragSelect();
                            }
                            evt.stopPropagation();
                        }
                    } 
                }
        
                function mouseMove(evt){
                    var x = evt.clientX;
                    var y = evt.clientY;
                    // var viewport = {t: $comb_scroll.offsetTop + 10,
                    //                 b: $comb_scroll.offsetTop +  $comb_scroll.clientHeight - 10,
                    //                 l: $comb_scroll.offsetLeft + 10,
                    //                 r: $comb_scroll.offsetLeft + $comb_scroll.clientWidth - 10,
                    // };
                    // switch (true){
                    //     case (y < viewport.t):
                    //         scroll.scrollTop = parseInt(scroll.scrollTop, 10) - 5;
                    //         y += 5;
                    //         break;
                    //     case (y > viewport.b):
                    //         scroll.scrollTop = parseInt(scroll.scrollTop, 10) + 5;
                    //         y -= 5;
                    //         break;
                    //     case (x < viewport.l):
                    //         scroll.scrollLeft = parseInt(scroll.scrollLeft, 10) - 5;
                    //         x += 5;
                    //         break;
                    //     case (x > viewport.r):
                    //         scroll.scrollLeft = parseInt(scroll.scrollLeft, 10) + 5;
                    //         x -= 5;
                    //         break;
                    // }
        
                    var moveXY = {
                        x: x - mouseOrigin.x,
                        y: y - mouseOrigin.y
                    };
                    $(selected_artefact).parent().parent().parent().parent().css('transform', 'translate3d(' + moveXY.x + 'px, ' + moveXY.y + 'px, 0px)');
                }
        
                function mouseUp(evt) {
                    evt.preventDefault();
                    $comb_scroll.off('mousemove', mouseMove);
                    $comb_scroll.off('mouseup', mouseUp);
                    var x = evt.clientX;
                    var y = evt.clientY;
                    var moveXY = {
                        x: x - mouseOrigin.x,
                        y: y - mouseOrigin.y
                    };
                    var $frag_cont = $(selected_artefact).parent().parent().parent().parent();
                    $frag_cont.css({
                        top: (parseInt($frag_cont.css('top')) + moveXY.y) + 'px',
                        left: (parseInt($frag_cont.css('left')) + moveXY.x) + 'px',
                        transform: 'initial'});
                    $frag_cont.data('y_loc', parseInt($frag_cont.css('top')) / zoom_factor);
                    $frag_cont.data('x_loc', ((scroll_width * zoom_factor) - parseInt($frag_cont.css('left')) - $frag_cont.width()) / zoom_factor);
                    var scroll_data = new FormData();
                    scroll_data.append('transaction', 'setArtPosition');
                    scroll_data.append('scroll_id', Spider.current_combination);
                    scroll_data.append('version', Spider.current_version);
                    scroll_data.append('version_id',scroll_version_id);
                    scroll_data.append('art_id', $frag_cont.attr("id").split("image-cont-xy-")[1]);
                    scroll_data.append('x', ((scroll_width * zoom_factor) - parseInt($frag_cont.css('left')) - $frag_cont.width()) / zoom_factor);
                    scroll_data.append('y', parseInt($frag_cont.css('top')) / zoom_factor);
                    scroll_data.append("SESSION_ID", Spider.session_id);
                    jQuery.ajax({
                        url: 'resources/cgi-bin/GetImageData.pl',
                        context: this,
                        data: scroll_data,
                        cache: false,
                        contentType: false,
                        processData: false,
                        type: 'POST',
                        success: function(selected_artefacts){
                            stopFragSelect();
                            $frag_cont.attr("id", "image-cont-xy-" + selected_artefacts.returned_info);
                            $comb_scroll.on('mousedown', mouseDown);
                            $comb_scroll.on('mousemove', mousehover);
                        }
                    });
                }

                function stopFragSelect() {
                    $(focused_element).parent().css('opacity', 1.00);
                    $(focused_element).parent().next().css('visibility', 'hidden');
                    focused_element = undefined;
                    $osd.css('visibility', 'hidden');
                }
            }
    
            function zoom(new_zoom, dynamic){
                zoom_differential = new_zoom / zoom_factor;
                zoom_factor = new_zoom;
                $comb_scroll.css('width', (scroll_width * zoom_factor) + 'px');
                $comb_scroll.css('height', (scroll_height * zoom_factor) + 'px');
                artefacts.forEach(function(artefact, index){
                    var scale = (scroll_dpi / artefact.dpi) * zoom_factor;
                    artefact.path.setAttribute('transform', 'scale(' + scale + ')');
                    if (!dynamic){
                        if (max_zoom < zoom_factor) {
                            artefact.image.setAttributeNS("http://www.w3.org/1999/xlink", 'xlink:href', "https://134.76.19.179/cgi-bin/sqe-iiif.pl?user=" + Spider.user + "&url=" + artefact.url + "&file="
                            + artefact.filename + '/' + artefact.crop_x + ',' + artefact.crop_y + ',' + artefact.crop_width + ',' + artefact.crop_height + '/pct:' + (scale * 100 < 100 ? scale * 100 : 100) + '/0/' + artefact.suffix);
                            if (index === artefact.length -1){
                                max_zoom = zoom_factor;
                            }
                        }
                    }
                    artefact.image.setAttribute('width', artefact.width * scale);
                    artefact.image.setAttribute('height', artefact.height * scale);
                    artefact.container.setAttribute('width', artefact.width * scale);
                    artefact.container.setAttribute('height', artefact.height * scale);
                    var $frag_cont = $(artefact.container).parent().parent();
                    $frag_cont.css({
                        top: (parseFloat($frag_cont.data('y_loc')) * zoom_factor) + 'px',
                        left: (scroll_width * zoom_factor) - (parseFloat($frag_cont.data('x_loc')) * zoom_factor) - (artefact.width * scale) + 'px'});
                });
            }
    
            //Public methods are created via the prototype
            CombinationController.prototype.display_scroll = function (id, scroll_version) {
                return load_scroll.call(this, id, scroll_version);
            };
            CombinationController.prototype.change_zoom = function (new_zoom, dynamic) {
                return zoom.call(this, new_zoom, dynamic);
            };
            // CombinationController.prototype.setOpacity = function(value, filename) {
            // 	$('#single_image-' + $.escapeSelector(filename)).css("opacity", value / 100);
            // }
            // CombinationController.prototype.toggle_image = function(file, eye_icon){
            // 	if ($('#single_image-' + $.escapeSelector(file)).length == 0){
            // 		display_image(file, eye_icon.dataset.url);
            // 		eye_icon.setAttribute("src", "resources/images/eye-open.png");
            // 		eye_icon.setAttribute("alt", "visible");
            // 	} else {
            // 		if ($('#single_image-' + $.escapeSelector(file)).css("visibility") == "visible"){
            // 			$('#single_image-' + $.escapeSelector(file)).css("visibility", "hidden");
            // 			eye_icon.setAttribute("src", "resources/images/eye-closed.png");
            // 			eye_icon.setAttribute("alt", "not visible");
            // 		} else {
            // 			$('#single_image-' + $.escapeSelector(file)).css("visibility", "visible");
            // 			eye_icon.setAttribute("src", "resources/images/eye-open.png");
            // 			eye_icon.setAttribute("alt", "visible");
            // 		}
            // 	}
            // }
    
            //register responders with messageSpider
            Spider.register_object([
                {type: 'load_scroll', execute_function: function(data){
                    self.display_scroll(data.id, data.scroll_version);
                    }
                }
            ]);
        }
        return CombinationController;
    })();
