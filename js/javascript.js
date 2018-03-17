// Get the container element
var btnContainer = document.getElementById("balls-bar");

// Get all buttons with class="btn" inside the container
var btns = btnContainer.getElementsByClassName("ball");

// Loop through the buttons and add the active class to the current/clicked button
for (var i = 0; i < btns.length; i++) {
    btns[i].addEventListener("click", function() {
        // var current = document.getElementsByClassName("ball-selected");
        // current[0].className = current[0].className.replace("ball-selected", "");
        this.className += " ball-selected";
    });
}

function deleteBall(){
    // Get all buttons with class="btn" inside the container
    var btns = btnContainer.getElementsByClassName("ball-selected");
    for (var i = 0; i < btns.length; i++) {
            var current = document.getElementsByClassName("ball-selected");
            current[0].className = current[0].className.replace("ball-selected", "");
    }
}