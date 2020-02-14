# Printix Power BI Solution Template
The Printix Power BI solution Template is designed to give you insights into your Print usage and contains visualizations of
data regarding users, workstation, printers, print queues and much more.

This solution contains multiple key components;
* A Power BI solution Template.
* A set of PowerPoint design templates and icons.

The most simple usage of this Power BI template consists of opening it and analyzing your Printix data in PowerBI
Desktop on your own machine.
Further, you can decide to publish it to your organization's online Power BI service in order to share the report with
other users (or even guests), embed visuals into your application, etc.

## Demo
A demo of the Printix solution template can be viewed [here](https://app.powerbi.com/view?r=eyJrIjoiNDRkYzNlOTMtMzcwZC00ODY4LWE5MGQtMzJlMWU2MDk5M2NmIiwidCI6IjNlYWFmMWQzLTZmOWUtNDBmZC1iN2U5LTYwYjQ1ZTU1ZTEyNSIsImMiOjh9).

# Getting started
To start using the Printix Power BI solution, follow the steps described in the Printix Administrator Manual:
1. [Setup Printix Analytics](https://manuals.printix.net/administrator/topic/how-to-setup-analytics)
2. [Setup Power BI](https://manuals.printix.net/administrator/topic/how-to-setup-power-bi)
3. (Optional) [Publish the report to Power BI Service](https://manuals.printix.net/administrator/topic/how-to-publish-to-power-bi-on-the-web)

Read more about what you can find in the report [here](https://manuals.printix.net/administrator/topic/how-to-interact-with-power-bi-report).

**Note:** When you change the "Display Currency" parameter, you will have to manually refresh the whole report. Just clicking "apply" in the report is not enough.

# How the cost calculation is done
It's impossible to actually calculate the total cost of printer environment, as there is loads of variables that's not tracked by Printix, such as direct print. But, we can try to calculate cost based on what's being printed through Printix.

To allow anyone to define their own cost for different variables you must provide some input the first time you set up the report:
- Sheet cost
  - Cost per sheet printed
- Toner cost BW
  - Cost per page, printed in black and white
- Toner cost Color
  - Cost per page, printed with colors
- Display Currency
  - Which currency would you like to display for all cost related columns.

From there, it's quite simple;
Based on actually printed jobs (Jobs table) we calculate the cost the following way:
- Sheet cost
  -   This takes into consideration if the job is duplex or not, and multiples the sum of pages with the cost per sheet.

  Code:
  ``   SWITCH(
TRUE ();
jobs[duplex] = TRUE(); ROUNDUP(jobs[page_count] / 2;0 )  * sum('Cost Per Sheet'[Cost Per Sheet]);
jobs[duplex] = FALSE(); (jobs[page_count]  * SUM('Cost Per Sheet'[Cost Per Sheet])
) + 0)`` 

- Cost per page, printed in black and white
  - If the job is printed in black and white, it will multiple the number of pages with the toner cost BW

    Code: 
``    SWITCH(
TRUE ();
jobs[color] = TRUE(); 0 ;
jobs[color] = FALSE(); (jobs[page_count]  * SUM('Cost Per Mono Sheet'[Cost Per Mono Sheet])
) + 0)``

- Cost per page, printed in color
  - If the job is printed in color, it will multiple the number of pages with the toner cost color

    Code: 
``    SWITCH(
TRUE ();
jobs[color] = TRUE(); 0 ;
jobs[color] = FALSE(); (jobs[page_count]  * SUM('Cost Per Mono Sheet'[Cost Per Mono Sheet])
) + 0)``

- Total cost
  - Sums all of the previously mentioned calculations to display the total cost per job.

    Code: ``Total_Cost = jobs[Sheet_Cost] + jobs[Toner_Cost_BW] + jobs[Toner_Cost_Color]``

For all 4 of these calculations, there is another column with the same name but with " (Currency formatted)" appended to it. These columns look's at the formatting of the selected display currency and make's the sum much more user friendly. It's these columns that's used for all the graphics.

**Note**; Merging the calculation and the formatting into a single measure has turned out to cause severe performance issues with larger datasets and should be avoided. 



# Editing the Power BI template
You can freely alter the Power BI templates as needed for your organization. If you create something awesome, we hope you will share it back with the community! Please remember that the report is shared under the [GPL-3.0 license](https://github.com/printix/Power-BI/blob/master/LICENSE).

## Changing the Power BI design
The Power BI design is created in PowerPoint and can easily be edited. You can find the design under the "PowerPoint" folder. The design is mostly built using Storyboards.

When you have altered the design in PowerPoint, and exported the slides as "PNGs", you can set them as background images in Power BI. This is done from the "Visualizations" view. Remember to set the "image fit" selector to "fit". 
The Images from PowerPoint is saved under the 'Images\PowerPoint' directory.

 ![AlterDateRanges](./Images/Documentation/PowerBI_Visualization.PNG)

 ## Changing the Power BI Theme
 The theme for the report is branded with the same style as [https://printix.net](https://printix.net). You can create your own report themes by following [Microsoft's official guide](https://docs.microsoft.com/en-us/power-bi/desktop-report-themes).

 The included theme is a great start for a customized template and is found under the themes folder. 