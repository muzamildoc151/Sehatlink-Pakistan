document.addEventListener("DOMContentLoaded", function () {
    const form = document.getElementById("caseForm");
    const payment = document.getElementById("payment");

    if (!form) {
        return;
    }

    form.addEventListener("submit", function (event) {
        event.preventDefault();

        // Generate a demo SehatLink case ID
        const caseId = "SL-" + Math.floor(100000 + Math.random() * 900000);

        const caseIdElement = document.getElementById("caseId");

        if (caseIdElement) {
            caseIdElement.textContent = caseId;
        }

        // Hide the patient form
        form.classList.add("hidden");

        // Hide progress indicator
        const progress = document.querySelector(".progress");

        if (progress) {
            progress.classList.add("hidden");
        }

        // Show payment section
        if (payment) {
            payment.classList.remove("hidden");
        }

        // Move to top of page
        window.scrollTo({
            top: 0,
            behavior: "smooth"
        });
    });
});
