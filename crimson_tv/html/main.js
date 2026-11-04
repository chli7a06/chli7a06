var player;
var playerData;
var idleLogoData = window.CRIMSON_TV_CRIMSON_LOGO || window.AGENCY_ELEVATOR_LOGO_DATA || "";
$(document).ready(function() {
    var resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "crimson_tv";
    $.post("https://" + resourceName + "/pageLoaded", JSON.stringify({}))
    if (idleLogoData) {
        $("#tv-idle-logo").attr("src", idleLogoData);
    }
    ShowIdle();
})

function GetURLID(link) {
    if (link == null) return;
    let url = link.toString();
    var regExp = /^.*(youtu\.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
    var match = url.match(regExp);
    if (match && match[2].length == 11) {
        return {type: "youtube", id: match[2]};
    } 
    else if (url.split("twitch.tv/").length > 1) {
        
        return {type: "twitch", id: url.split("twitch.tv/")[1]};
    }
}

function ChannelDisplay(channel, channelFound) {
    if (channel) {
        var temp = 'CH<span style="font-size: 18pt !important;"> </span>'
        if (channel > 9) {
            temp += channel
        }
        else {
            temp += ("0" + channel)
        }
        $("#overlay span").show()
        $("#overlay span").html(temp)
    }
    else {
        $("#overlay span").show()
        $("#overlay span").html("")
    }
}

function DestroyPlayer() {
    if (player) {
        player.destroy()
        player = null
    }
    playerData = null
    $("#twitch-embed").empty()
}

function ShowIdle() {
    $("#tv-container").removeClass("notify")
    $("#tv-idle").show()
    $("#tv-notify").hide().text("")
    $("#tv-container").show()
}

function TurnOffDisplay() {
    DestroyPlayer()
    ChannelDisplay()
    ShowIdle()
}

function SetVideo(video_data) {
    var url = video_data.url;
    var channel = video_data.channel;
    var data = GetURLID(url)
    
    DestroyPlayer()
    playerData = data
    if (data) {
        if (data.type == "youtube") {
            player = new YT.Player('twitch-embed', {
                height: '100%',
                width: '100%',
                videoId: data.id,
                playerVars: {
                    'playsinline': 1,
                },
                events: {
                    'onReady': function(event) {
                        event.target.playVideo();
                        event.target.seekTo(video_data.time)
                    },
                    'onStateChange': function(event) {
                        if (event.data == YT.PlayerState.PLAYING) {
                            event.target.unMute();
                        }
                        else if (event.data == YT.PlayerState.PAUSED) {
                            
                        }
                    }
                }
            });
        }
        else if (data.type == "twitch") {
            player = new Twitch.Player("twitch-embed", {
                width: "100%",
                height: "100%",
                channel: data.id,
                volume: 1.0
            });
            player.addEventListener(Twitch.Embed.VIDEO_READY, function() {
                player.setMuted(false);
            });
        } 
        
        $("#overlay span").hide()
        $("#tv-container").hide()
    } else {
        TurnOffDisplay()
    }
    if (channel) {
        ChannelDisplay(channel, url)
    }
}

function SetVolume(volume) {
    
    if (player && playerData && player.setVolume) {
        if (playerData.type == "twitch") {
            player.setMuted(false);
            player.setVolume(volume / 100.0);
        }
        else if (playerData.type == "youtube") {
            player.unMute();
            player.setVolume(volume);
        }
    }
}

function ShowNotification(channel, data) {
    var display = $('#tv-container').is(':visible')
    $("#tv-container").addClass("notify")
    $("#tv-idle").hide()
    $('#tv-container').show()
    $("#tv-notify").text("Channel #" + channel + (data ? (" ("+data.name+")") : "") + " is now " + (data ? "live!" : "offline.")).show()

    setTimeout(function() {
        if (!display) {
            $('#tv-container').hide()
            $("#tv-container").removeClass("notify")
            $("#tv-notify").hide().text("")
            $("#tv-idle").show()
        }
        else {
            ShowIdle()
        }
    }, 3500)
}

window.addEventListener("message", function(ev) {
    if (ev.data.setVideo) {
        SetVideo(ev.data.data)
    }
    else if (ev.data.setVolume) {
        SetVolume(ev.data.data)
    }
    else if (ev.data.showNotification) {
        ShowNotification(ev.data.channel, ev.data.data)
    }
    else if (ev.data.turnOff) {
        TurnOffDisplay()
    }
})
$(document).ready(function() {
    ChannelDisplay()
})
