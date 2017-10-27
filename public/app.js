$(function () {
    $('article.project').each(function() {
        var $article = $(this),
            $project = $article.find('.field-name'),
            $tmpl = $article.find('.template');

        $.get('/p/' + $project.text(), function(data) {
            $article.find('.loading').remove();
            $.each(data, function(i,o) {
                var $service = $tmpl.clone().removeClass('template');
                $service.find('.field-container-name').text(o.container);
                $service.find('.field-container-status')
                    .text(o.up ? "Up" : "Not Up")
                    .addClass(o.up ? 'up' : 'not-up');
                $service.find('.field-url a')
                    .text(o.url)
                    .attr('href', o.url)
                    .addClass(o.up ? 'up' : 'not-up');

                $service.insertAfter($tmpl);
            });
        });
    });
});
