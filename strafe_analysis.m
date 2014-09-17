clear all; close all; clc; format compact;

TICK_RATE = 100.0;

lsData = import_strafe_analysis_file('strafeanalysis.txt');
lsData.Time = lsData.Tick/TICK_RATE;

%Example plot
figure;
title('Client positions over time');
plot3(lsData.OriginX,lsData.OriginY,lsData.OriginZ);
hold on; grid on;
lanFilt = find(lsData.MoveRHold == 1);
plot3(lsData.OriginX(lanFilt),lsData.OriginY(lanFilt),lsData.OriginZ(lanFilt),'g.');
lanFilt = find(lsData.MoveLHold == 1);
plot3(lsData.OriginX(lanFilt),lsData.OriginY(lanFilt),lsData.OriginZ(lanFilt),'k.');
lanFilt = find(lsData.JumpPress == 1);
plot3(lsData.OriginX(lanFilt),lsData.OriginY(lanFilt),lsData.OriginZ(lanFilt),'ro');
xlabel('X'); ylabel('Y'); zlabel('Z');
legend('Pos','Move right','Move left','Jump pressed');
